nconf = require("nconf")
analytics = require("analytics-node")
request = require("request")
users = require("./users")
apiErrors = require("../errors")

{Session} = require("../database")


# Session-related helpers

module.exports.createSession = createSession = (user, cb) ->
  session = new Session
    last_access: new Date
    keychain: {}

  session.user = user if user
  session.save(cb)


module.exports.loadSession = loadSession = (sessid, cb) ->
  return cb() unless sessid and sessid.length

  Session.findById(sessid).populate("user").exec (err, session) ->
    if err then cb(err)
    else unless session then cb()
    else if Date.now() - session.last_access.valueOf() > nconf.get("session:max_age")
      session.remove()
      cb()
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
    else next(new apiErrors.ImpossibleError)


module.exports.read = (req, res, next) ->
  loadSession req.params.id, (err, session) ->
    if err then next(new apiErrors.DatabaseError(err))
    else if session then res.json session.toJSON()
    else next(new apiErrors.ImpossibleError)


module.exports.create = (req, res, next) ->
  createSession null, (err, session) ->
    if err then next(new apiErrors.DatabaseError(err))
    else if session then res.json session.toJSON()
    else next(new apiErrors.ImpossibleError)


module.exports.setUser = (req, res, next) ->
  users.authenticateGithubToken req.param("token"), (err, ghuser) ->
    return next(new apiErrors.DatabaseError(err)) if err
    return next(new apiErrors.NotFound) unless ghuser

    userInfo =
      login: ghuser.login
      gravatar_id: ghuser.gravatar_id
      service_id: "github:#{ghuser.login}"

    users.upsert userInfo, (err, user) ->
      return next(new apiErrors.DatabaseError(err)) if err

      #analytics.identify user._id,
      #  username: user.login
      #  created: user.created_at

      req.session.user = user
      req.session.auth =
        service_name: "github"
        service_token: token
      req.session.save (err, session) ->
        if err then next(new apiErrors.DatabaseError(err))
        else res.json(session.toJSON(), 201)

module.exports.unsetUser = (req, res, next) ->
  req.session.user = null
  req.session.auth = null

  req.session.save (err, session) ->
    return next(apiErrors.DatabaseError(err)) if err

    res.json session.toJSON()