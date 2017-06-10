nconf = require("nconf")
request = require("request")
users = require("./users")
apiErrors = require("../errors")

{User, Plunk} = require("../database")



# User-related helpers

module.exports.authenticateGithubToken = authenticateGithubToken = (token, cb) ->
  return cb() unless token

  config =
    url: "https://api.github.com/user?access_token=#{token}"
    json: true
    timeout: 6000
    headers: { 'User-Agent': "plunker-api" }

  request.get config, (err, res, body) ->
    return cb(err) if err
    return cb(new apiErrors.PermissionDenied) if res.status >= 400

    cb(null, body)


module.exports.upsert = (userInfo, cb) ->
  query = service_id: userInfo.service_id
  update = (user) ->
    user.set(userInfo).save (err) -> cb(err, user)

  User.findOne(query, 'gravatar_id login service_id').exec (err, user) ->
    if err then cb(err)
    else if user then update(user)
    else update(new User)

# Fix plunks saved with invalid github:login style service_id's
module.exports.correct = (invalid_id, correct_id) ->
  User.findOne {service_id: invalid_id}, 'gravatar_id login service_id', (err, user) ->
    if err then console.log "[ERR] Failed to query for #{invalid_id}"
    else if user then Plunk.update {user: user._id}, {user: correct_id}, {multi: true}, (err, numAffected) ->
      console.log "[OK] Fixed #{numAffected} plunks by #{user.login} incorrectly attributed to #{invalid_id}"

      user.remove (err) ->
        if err then console.log "[ERR] Failed to remove duplicate user #{user.login}"
        else console.log "[OK] Removed duplicate user #{user.login}"



# User-related middleware

module.exports.withUser = withUser = (req, res, next) ->
  User.findOne({login: req.params.login}, 'gravatar_id login service_id').exec (err, user) ->
    return next(new apiErrors.DatabaseError(err)) if err
    return next(new apiErrors.NotFound) unless user

    req.user = user
    next()

module.exports.withCurrentUser = withCurrentUser = (req, res, next) ->
  return next(new apiErrors.NotFound) unless req.currentUser
  next()


# User-related request handlers

module.exports.read = (req, res, next) ->
  res.json req.user.toJSON()
