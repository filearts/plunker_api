nconf = require("nconf")
analytics = require("analytics-node")
request = require("request")
users = require("./users")
apiErrors = require("../errors")
_ = require("underscore")._

{Session} = require("../database")


MAX_AGE = 1000 * 60 * 60 * 24 * 7 * 2

# Session-related helpers

module.exports.prune = (cb = ->) ->
  Session.remove(last_access: $lt: Date.now() - MAX_AGE).exec(cb)

module.exports.createSession = createSession = (user, cb) ->
  session =
    last_access: new Date
    keychain: {}

  session.user = user._id if user
  
  Session.create(session, cb)


module.exports.loadSession = loadSession = (sessid, cb) ->
  return cb() unless sessid and sessid.length

  sessionData =
    last_access: Date.now()
    expires_at: Date.now() + 1000 * 60 * 60 * 24 * 7 * 2 # Two weeks
    
  query = Session.findByIdAndUpdate sessid, sessionData
  query.populate("user")
  query.exec (err, session) ->
    if err then cb(err)
    else cb(null, session)



# Session-related middleware

module.exports.withSession = (req, res, next) ->
  loadSession req.params.id, (err, session) ->
    if err then next(new apiErrors.DatabaseError(err))
    else unless session then next(new apiErrors.NotFound)
    else
      req.session = session
      next()



# Session-related request handlers

module.exports.findOrCreate = (req, res, next) ->
  if req.currentSession then res.json req.currentSession.toJSON()
  else createSession null, (err, session) ->
    if err then next(new apiErrors.DatabaseError(err))
    else if session then res.json session.toJSON()
    else
      console.log "[ERR] findOrCreate"
      next(new apiErrors.ImpossibleError)


module.exports.read = (req, res, next) ->
  loadSession req.params.id, (err, session) ->
    if err then next(new apiErrors.DatabaseError(err))
    else if session then res.json session.toJSON()
    else next(new apiErrors.NotFound)


module.exports.create = (req, res, next) ->
  createSession null, (err, session) ->
    if err then next(new apiErrors.DatabaseError(err))
    else if session then res.json session.toJSON()
    else
      console.log "[ERR] createSession"
      next(new apiErrors.ImpossibleError)


module.exports.setUser = (req, res, next) ->
  token = req.param("token")
  users.authenticateGithubToken token, (err, ghuser) ->
    return next(new apiErrors.DatabaseError(err)) if err
    return next(new apiErrors.NotFound) unless ghuser
    
    userInfo =
      login: ghuser.login
      gravatar_id: ghuser.gravatar_id
      service_id: "github:#{ghuser.id}"

    users.upsert userInfo, (err, user) ->
      return next(new apiErrors.DatabaseError(err)) if err
      return next(new apiErrors.NotFound) unless user
      
      users.correct("github:#{ghuser.login}", user._id)

      #analytics.identify user._id,
      #  username: user.login
      #  created: user.created_at
      
      req.session.user = user._id
      req.session.auth =
        service_name: "github"
        service_token: token
      req.session.save (err, session) ->
        if err then next(new apiErrors.DatabaseError(err))
        else if session then res.json(201, _.extend(session.toJSON(), user: user.toJSON()))
        else
          console.log "[ERR] setUser->session.save", arguments...
          next(new apiErrors.ImpossibleError)

        

module.exports.unsetUser = (req, res, next) ->
  req.session.user = null
  req.session.auth = null

  req.session.save (err, session) ->
    if err then next(apiErrors.DatabaseError(err)) 
    else if session then res.json session.toJSON()
    else
      console.log "[ERR] unsetUser->session.save", arguments...
      next(new apiErrors.ImpossibleError)
    