nconf = require("nconf")
request = require("request")
users = require("./users")
apiErrors = require("../errors")

{User} = require("../database")



# User-related helpers

module.exports.authenticateGithubToken = authenticateGithubToken = (token, cb) ->
  return cb() unless token

  config =
    url: "https://api.github.com/user?access_token=#{token}"
    json: true
    timeout: 6000

  request.get config, (err, res, body) ->
    return cb(err) if err
    return cb(new apiErrors.PermissionDenied) if res.status >= 400

    cb(null, body)


module.exports.upsert = (userInfo, cb) ->
  query = service_id: userInfo.service_id
  options = upsert: true

  User.update(query, userInfo, options, cb)



# User-related middleware

module.exports.withUser = withUser = (req, res, next) ->
  User.findOne({login: req.params.login}).exec (err, user) ->
    return next(new apiErrors.DatabaseError(err)) if err
    return next(apiErrors.NotFound) unless user

    req.user = user
    next()


# User-related request handlers

module.exports.read = (req, res, next) ->
  res.json req.user.toJSON()