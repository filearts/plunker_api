nconf = require("nconf")
sessions = require("../resources/sessions")
errors = require("../errors")

module.exports.middleware = (config = {}) ->
  (req, res, next) ->
    if req.query.sessid then sessid = req.query.sessid
    else if auth = req.get("authorization") then [header, sessid] = auth.match(/^token (\S+)$/i)
    
    sessions.loadSession sessid, (err, session) ->
      return next(err) if err
      return next() unless session

      session.last_access = new Date

      req.currentSession = session
      req.currentUser = session.user if session.user
      
      next()
      
      session.save() # We do this after passing on the route and don't worry about success