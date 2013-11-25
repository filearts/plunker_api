nconf = require("nconf")
sessions = require("../resources/sessions")
errors = require("../errors")

module.exports.middleware = (config = {}) ->
  (req, res, next) ->
    if req.query.sessid then sessid = req.query.sessid
    else if auth = req.get("authorization") then [header, sessid] = auth.match(/^token (\S+)$/i)
    
    if sessid
      sessions.loadSession sessid, (err, session) ->
        return next(err) if err
        return next() unless session
  
        req.currentSession = session
        req.currentUser = session.user if session.user
        
        next()
    else
      next()