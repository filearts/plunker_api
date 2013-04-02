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
  version:
    create: gate.createSchema(require("./schema/packages/versions/create.json"))
    update: gate.createSchema(require("./schema/packages/versions/create.json"))

createLinkHeaderString = (baseUrl, page, pages, limit) ->
  link = []
  
  if page < pages
    link.push "<#{baseUrl}?p=#{page+1}&pp=#{limit}>; rel=\"next\""
    link.push "<#{baseUrl}?p=#{pages}&pp=#{limit}>; rel=\"last\""
  if page > 1
    link.push "<#{baseUrl}?p=#{page-1}&pp=#{limit}>; rel=\"prev\""
    link.push "<#{baseUrl}?p=1&pp=#{limit}>; rel=\"first\""
  
  link.join(", ")

preparePackage = (pkg, json, options) ->
  # This is a sub-document of the pkg
  return json if 'function' == typeof pkg.ownerDocument

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
  return next(apiErrors.NotFound) unless req.currentUser
  
  loadPackage {name: req.params.name, maintainers: req.currentUser.login}, (err, pkg) ->
    if err then next(new apiErrors.DatabaseError(err))
    else unless pkg then next(new apiErrors.NotFound)
    else
      req.pkg = pkg
      next()


exports.createListing = (config) ->
  options = {}
  
  options.baseUrl ||= "#{apiUrl}/catalogue/packages"
  options.query ||= {}

  (req, res, next) ->
    options = _.extend options, config(req, res) if config
    
    page = parseInt(req.params.p or 1, 10)
    limit = parseInt(req.params.pp or 12, 10)

    # Build the Mongoose Query
    query = Package.find(options.query)
    query.sort(options.sort or {name: 1})
    
    query.paginate page, limit, (err, packages, count, pages, current) ->
      if err then next(new apiErrors.DatabaseError(err))
      else
        res.header "link", createLinkHeaderString(options.baseUrl, current, pages, limit)
        res.json preparePackages(req.currentSession, packages)



# Request handlers

exports.create = (req, res, next) ->
  pkg = new Package(req.body)
  pkg.maintainers.push(req.currentUser.login)
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
  loadPackage {name: req.params.name}, (err, pkg) ->
    if err then next(new apiErrors.DatabaseError(err))
    else unless pkg then next(new apiErrors.NotFound)
    else if pkg
      json = pkg.toJSON
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