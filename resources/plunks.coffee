_ = require("underscore")._
nconf = require("nconf")
genid = require("genid")
diff_match_patch = require("googlediff")
gate = require("json-gate")
analytics = require("analytics-node")



gdiff = new diff_match_patch()
apiErrors = require("../errors")
apiUrl = nconf.get('url:api')
database = require("../database")

{Plunk} = database



exports.schema =
  create: gate.createSchema(require("./schema/plunks/create.json"))
  fork: gate.createSchema(require("./schema/plunks/fork.json"))
  update: gate.createSchema(require("./schema/plunks/update.json"))

createLinksObject = (baseUrl, page, pages, limit) ->
  links = {}

  if page < pages
    links.next = "#{baseUrl}?p=#{page+1}&pp=#{limit}"
    links.last = "#{baseUrl}?p=#{pages}&pp=#{limit}"
  if page > 1
    links.prev "#{baseUrl}?p=#{page-1}&pp=#{limit}"
    links.first "#{baseUrl}?p=1&pp=#{limit}"

  links

createEvent = (type, user) ->
  event =
    event: type or "create"
    changes: []

  event.user = user._id if user

  event


ownsPlunk = (session, json) ->
  owner = false

  if session
    owner ||= !!(json.user and session.user and json.user is session.user._id)
    owner ||= !!(json.user and session.user and json.user.login is session.user.login)
    owner ||= !!(session.keychain and session.keychain.id(json.id)?.token is json.token)

  owner

saveNewPlunk = (plunk, cb) ->
  # Keep generating new ids until not taken
  savePlunk = ->
    plunk._id = if !!plunk.private then genid(20) else genid(6)

    plunk.save (err) ->
      if err
        if err.code is 11000 then savePlunk()
        else
          console.error "[ERR]", err.message, err
          return cb(new apiErrors.DatabaseError(err))
      else return cb(null, plunk)

  savePlunk()

populatePlunk = (json, options = {}) ->
  plunk = options.plunk or new Plunk
  plunk.description = json.description or "Untitled"
  plunk.private = json.private ? true
  plunk.source = json.source
  plunk.user = options.user._id if options.user
  plunk.fork_of = options.parent._id if options.parent
  plunk.tags.push(tag) for tag in json.tags unless options.skipTags
  
  unless options.skipFiles then for filename, file of json.files
    plunk.files.push
      filename: file.filename or filename
      content: file.content

  plunk

preparePlunk = (plunk, json, options) ->
  # This is a sub-document of the plunk
  return json if 'function' == typeof plunk.ownerDocument

  delete json.token unless ownsPlunk(options.session, plunk)
  delete json.voters
  delete json._id
  delete json.__v
  
  if json.files then json.files = do ->
    files = {}
    for file in json.files
      file.raw_url = "#{json.raw_url}#{file.filename}"
      files[file.filename] = file
    files

  json.thumbed = options.session?.user? and plunk.voters?.indexOf("#{options.session.user._id}") >= 0

  json

preparePlunks = (session, plunks) ->
  _.map plunks, (plunk) ->
    plunk.toJSON
      session: session
      transform: preparePlunk
      virtuals: true
      getters: true

applyFilesDeltaToPlunk = (plunk, json) ->
  oldFiles = {}
  changes = []
  
  return changes unless json.files

  # Create a map of filename=>file (subdocument) of existing files
  for file, index in plunk.files
    oldFiles[file.filename] = file
  
  # For each change proposed in the json
  for filename, file of json.files
  
    # Attempt to delete
    if file is null
      if old = oldFiles[filename]
        changes.push
          pn: filename
          pl: old.content
        oldFiles[filename].remove() 
        
    # Modification to an existing file
    else if old = oldFiles[filename]
      chg =
        pn: old.filename
        fn: file.filename or old.filename
      
      if file.filename
        old.filename = file.filename
      if file.content?
        chg.pl = gdiff.patch_toText(gdiff.patch_make(file.content, old.content))
        old.content = file.content
      
      if chg.fn or file.filename
        changes.push(chg)
        
    # New file; handle only if content provided
    else if file.content
      changes.push
        fn: filename
        pl: file.content
      plunk.files.push
        filename: filename
        content: file.content
  
  changes

applyTagsDeltaToPlunk = (plunk, json) ->
  changes = []
  
  if json.tags
    plunk.tags ||= []
    
    for tagname, add of json.tags
      if add
        plunk.tags.push(tagname)
      else
        plunk.tags.splice(idx, 1) if (idx = plunk.tags.indexOf(tagname)) >= 0
  
  changes
  



exports.loadPlunk = loadPlunk = (id, cb) ->
  return cb() unless id and id.length

  Plunk.findById(id).populate("user").populate("history.user").exec (err, plunk) ->
    if err then cb(err)
    else unless plunk then cb()
    else cb(null, plunk)


exports.withPlunk = (req, res, next) ->
  loadPlunk req.params.id, (err, plunk) ->
    if err then next(new apiErrors.DatabaseError(err))
    else unless plunk then next(new apiErrors.NotFound)
    else
      req.plunk = plunk
      next()

exports.ownsPlunk = (req, res, next) ->
  unless ownsPlunk(req.currentSession, req.plunk) then next(new apiErrors.NotFound)
  else next()
  

exports.createListing = (config) ->
  options = {}
  
  options.baseUrl ||= "#{apiUrl}/plunks"
  options.query ||= {}

  (req, res, next) ->
    options = _.extend options, config(req, res) if config
    
    page = parseInt(req.param("p", "1"), 10)
    limit = parseInt(req.param("pp", "8"))

    # Filter on plunks that are visible to the active user
    if req.currentUser
      options.query.$or = [
        'private': $ne: true
      ,
        user: req.currentUser._id
      ]
    else
      options.query.private = $ne: true

    # Build the Mongoose Query
    query = Plunk.find(options.query)
    query.sort(options.sort or {updated_at: -1})
    query.select("-files") # We exclude files from plunk listings
    query.select("-history") # We exclude history from plunk listings
    
    query.populate("user").paginate page, limit, (err, plunks, count, pages, current) ->
      if err then next(new apiErrors.DatabaseError(err))
      else
        res.links createLinksObject(options.baseUrl, current, pages, limit)
        res.json preparePlunks(req.currentSession, plunks)



# Request handlers

exports.read = (req, res, next) ->
  loadPlunk req.params.id, (err, plunk) ->
    if err then next(new apiErrors.DatabaseError(err))
    else unless plunk then next(new apiErrors.NotFound)
    else if plunk then res.json plunk.toJSON
      session: req.currentSession
      transform: preparePlunk
      virtuals: true
      getters: true

exports.create = (req, res, next) ->
  event = createEvent("create", req.currentUser)

  plunk = populatePlunk(req.body, user: req.currentUser)
  plunk.history.push(event)

  saveNewPlunk plunk, (err, plunk) ->
    if err then next(new apiErrors.DatabaseError(err))
    else
      unless req.user and req.currentSession and req.currentSession.keychain
        req.currentSession.keychain.push _id: plunk._id, token: plunk.token
        req.currentSession.save()

      json = plunk.toJSON
        session: req.currentSession
        transform: preparePlunk
        virtuals: true
        getters: true
        
      json.user = req.currentUser.toJSON() if req.currentUser
      json.history[json.history.length - 1].user = req.currentUser.toJSON() if req.currentUser

      res.json(201, json)




exports.update = (req, res, next) ->
  return next(new Error("request.plunk is required for update()")) unless req.plunk
  
  event = createEvent "update", req.currentUser
  event.changes.push(e) for e in applyFilesDeltaToPlunk(req.plunk, req.body)
  event.changes.push(e) for e in applyTagsDeltaToPlunk(req.plunk, req.body)
              
  req.plunk.updated_at = new Date
  req.plunk.description = req.body.description if req.body.description
  req.plunk.user = req.currentUser._id if req.currentUser
  
  req.plunk.history.push(event)
        
  req.plunk.save (err, plunk) ->
    if err then next(new apiErrors.DatabaseError(err))
    else
      
      json = plunk.toJSON
        session: req.currentSession
        transform: preparePlunk
        virtuals: true
        getters: true
        
      json.history[json.history.length - 1].user = req.currentUser.toJSON() if req.currentUser
      
      res.json json


exports.fork = (req, res, next) ->
  return next(new Error("request.plunk is required for update()")) unless req.plunk
  
  event = createEvent "fork", req.currentUser
  
  if req.apiVersion is 1
    json = req.plunk.toJSON()
    json.description = req.body.description if req.body.description
    
    event.changes.push(e) for e in applyFilesDeltaToPlunk(json, req.body)
    event.changes.push(e) for e in applyTagsDeltaToPlunk(json, req.body)
    
  else if req.apiVersion is 0
    json = req.body

  
  fork = populatePlunk(json, user: req.currentUser, parent: req.plunk)
  fork.history.push(evt) for evt in req.plunk.history
  fork.history.push(event)
  
  saveNewPlunk fork, (err, plunk) ->
    if err then next(new apiErrors.DatabaseError(err))
    else
      unless req.currentUser and req.currentSession and req.currentSession.keychain
        req.currentSession.keychain.push _id: plunk._id, token: plunk.token
        req.currentSession.save()
      
      json = plunk.toJSON
        session: req.currentSession
        transform: preparePlunk
        virtuals: true
        getters: true
        
      json.user = req.currentUser.toJSON() if req.currentUser
      json.history[json.history.length - 1].user = req.currentUser.toJSON() if req.currentUser

      res.json(201, json)
      
      # Update the forks of the parent after the request is sent
      # No big deal if the forks update fails
      req.plunk.forks.push(plunk._id)
      req.plunk.save()

exports.destroy = (req, res, next) ->
  return next(new Error("request.plunk is required for update()")) unless req.plunk
  
  if req.plunk.fork_of then loadPlunk req.plunk.fork_of, (err, parent) ->
    parent.forks.remove(req.plunk.fork_of)

  unless ownsPlunk(req.currentSession, req.plunk) then next(new apiErrors.NotFound)
  else req.plunk.remove ->
    res.send(204)
    

calculateScoreDelta = (count, delta = 1) ->
  baseIncrement = 1000 * 60 * 60 * 12 # The first vote will move the plunk forward 12 hours in time
  decayFactor = 4
  
  (baseIncrement * Math.E ^ (-(count + delta) / decayFactor)) - (baseIncrement * Math.E ^ (-(count) / decayFactor))

exports.setThumbed = (req, res, next) ->
  return next(new apiErrors.PermissionDenied) unless req.currentUser
  
  req.plunk.score ||= req.plunk.created_at.valueOf()
  req.plunk.thumbs ||= 0
  
  req.plunk.voters.addToSet(req.currentUser._id)
  req.plunk.score += calculateScoreDelta(req.plunk.thumbs)
  req.plunk.thumbs++
  
  req.plunk.save (err, plunk) ->
    if err then next(new apiErrors.DatabaseError(err))
    else res.json({ thumbs: plunk.get("thumbs"), score: plunk.score}, 201)

exports.unsetThumbed = (req, res, next) ->
  return next(new apiErrors.PermissionDenied) unless req.currentUser
  
  unless 0 > req.plunk.voters.indexOf(req.currentUser._id)
    req.plunk.voters.remove(req.currentUser._id)
    req.plunk.score -= calculateScoreDelta(req.plunk.thumbs)
    req.plunk.thumbs--
  
  req.plunk.save (err, plunk) ->
    if err then next(new apiErrors.DatabaseError(err))
    else res.json({ thumbs: plunk.get("thumbs"), score: plunk.score}, 200)