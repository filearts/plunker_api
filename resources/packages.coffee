nconf = require("nconf")
analytics = require("analytics-node")
users = require("./users")
apiErrors = require("../errors")
gate = require("json-gate")
semver = require("semver")
_ = require("underscore")._

{Package} = require("../database")

apiUrl = nconf.get("url:api")


exports.schema =
  create: gate.createSchema(require("./schema/packages/create.json"))
  update: gate.createSchema(require("./schema/packages/update.json"))
  versions:
    create: gate.createSchema(require("./schema/packages/versions/create.json"))
    update: gate.createSchema(require("./schema/packages/versions/update.json"))

createLinksObject = (baseUrl, page, pages, limit) ->
  links = {}

  if page < pages
    links.next = "#{baseUrl}?p=#{page+1}&pp=#{limit}"
    links.last = "#{baseUrl}?p=#{pages}&pp=#{limit}"
  if page > 1
    links.prev = "#{baseUrl}?p=#{page-1}&pp=#{limit}"
    links.first = "#{baseUrl}?p=1&pp=#{limit}"

  links

preparePackage = (pkg, json, options) ->
  # This is a sub-document of the pkg
  return json if 'function' == typeof pkg.ownerDocument
  
  json.maintainer = true if options.session?.user?.login# in json.maintainers

  delete json._id
  delete json.__v
  
  json

preparePackages = (session, pkgs) ->
  _.map pkgs, (pkg) ->
    pkg.toJSON
      session: session
      transform: preparePackage
      virtuals: true
      getters: true



module.exports.loadPackage = loadPackage = (query, cb) ->
  return cb() unless query

  Package.findOne(query).exec (err, pkg) ->
    if err then cb(err)
    else unless pkg then cb()
    else cb(null, pkg)



# Package-related middleware

module.exports.withPackage = (req, res, next) ->
  loadPackage {name: req.params.name}, (err, pkg) ->
    if err then next(new apiErrors.DatabaseError(err))
    else unless pkg then next(new apiErrors.NotFound)
    else
      req.pkg = pkg
      next()

module.exports.withOwnPackage = (req, res, next) ->
  console.log "withOwnPackage", req.currentUser?
  return next(new apiErrors.NotFound) unless req.currentUser
  
  #loadPackage {name: req.params.name, maintainers: req.currentUser.login}, (err, pkg) ->
  loadPackage {name: req.params.name}, (err, pkg) ->
    if err then next(new apiErrors.DatabaseError(err))
    else unless pkg then next(new apiErrors.NotFound)
    else
      req.pkg = pkg
      next()


exports.createListing = (config = {}) ->
  (req, res, next) ->
    options = 
      if _.isFunction(config) then options = config(req, res)
      else angular.copy(config)
    
    options.baseUrl ||= "#{apiUrl}/catalogue/packages"
    options.query ||= {}
    
    page = parseInt(req.param("p", "1"), 10)
    limit = parseInt(req.param("pp", "8"), 10)

    # Build the Mongoose Query
    query = Package.find(options.query)
    query.sort(options.sort or {bumps: -1})
    
    query.paginate page, limit, (err, packages, count, pages, current) ->
      if err then next(new apiErrors.DatabaseError(err))
      else
        res.links createLinksObject(options.baseUrl, current, pages, limit)
        res.json preparePackages(req.currentSession, packages)



# Request handlers

exports.create = (req, res, next) ->
  pkg = new Package(req.body)
  pkg.maintainers.push(req.currentUser.login) if req.currentUser?.login
  pkg.save (err, pkg) ->
    if err
      if err.code is 11000 then next(new apiErrors.ResourceExists)
      else next(new apiErrors.DatabaseError(err))
    else
      json = pkg.toJSON
        session: req.currentSession
        transform: preparePackage
        virtuals: true
        getters: true

      res.json(201, json)


exports.read = (req, res, next) ->
  if req.param("bump")
    req.pkg.update({$inc: {bumps: 1}}) # Send asynch request to update db copy
    req.pkg.bumps++
  
  json = req.pkg.toJSON
    session: req.currentSession
    transform: preparePackage
    virtuals: true
    getters: true
  
  res.json json



exports.update = (req, res, next) ->
  req.pkg.set(req.body).save (err, pkg) ->
    if err then next(new apiErrors.DatabaseError(err))
    else
      json = pkg.toJSON
        session: req.currentSession
        transform: preparePackage
        virtuals: true
        getters: true
      
      res.json json


exports.bump = (req, res, next) ->
  req.pkg.bumps++
  
  json = req.pkg.toJSON
    session: req.currentSession
    transform: preparePackage
    virtuals: true
    getters: true
  
  res.json json

  req.pkg.update({$inc: {bumps: 1}}).exec() # Send asynch request to update db copy

exports.destroy = (req, res, next) ->
  req.pkg.remove (err) ->
    if err then next(new apiErrors.DatabaseError(err))
    else res.send(204)
    

exports.addMaintainer = (req, res, next) ->
  req.pkg.maintainers.push(req.body.login)
  req.pkg.save (err, pkg) ->
    if err then next(new apiErrors.DatabaseError(err))
    else
      json = pkg.toJSON
        session: req.currentSession
        transform: preparePackage
        virtuals: true
        getters: true
      
      res.json 201, json


exports.removeMaintainer = (req, res, next) ->
  req.pkg.maintainers.pull(req.body.login)
  req.pkg.save (err, pkg) ->
    if err then next(new apiErrors.DatabaseError(err))
    else
      json = pkg.toJSON
        session: req.currentSession
        transform: preparePackage
        virtuals: true
        getters: true
      
      res.json 200, json

exports.versions = {}

exports.versions.create = (req, res, next) ->
  req.pkg.versions.push(req.body)
  req.pkg.save (err, pkg) ->
    if err then next(new apiErrors.DatabaseError(err))
    else
      json = pkg.toJSON
        session: req.currentSession
        transform: preparePackage
        virtuals: true
        getters: true
      
      res.json 201, json

# There is no specific versions.read

exports.versions.update = (req, res, next) ->
  version = _.find req.pkg.versions, (ver) -> ver.semver == req.params.semver
  
  return next(new apiErrors.NotFound) unless version

  _.extend version, req.body
  
  req.pkg.save (err, pkg) ->
    if err then next(new apiErrors.DatabaseError(err))
    else
      json = pkg.toJSON
        session: req.currentSession
        transform: preparePackage
        virtuals: true
        getters: true
      
      res.json 200, json


exports.versions.destroy = (req, res, next) ->
  version = _.find req.pkg.versions, (ver) -> ver.semver == req.params.semver
  
  return next(new apiErrors.NotFound) unless version
  
  req.pkg.versions.remove(version)
  
  req.pkg.save (err, pkg) ->
    if err then next(new apiErrors.DatabaseError(err))
    else
      json = pkg.toJSON
        session: req.currentSession
        transform: preparePackage
        virtuals: true
        getters: true
      
      res.json 200, json