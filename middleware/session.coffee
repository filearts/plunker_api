nconf = require("nconf")
sessions = require("../resources/sessions")
errors = require("../errors")

badSessions = ["52a56d9f1aeed79fe80163ea"]

module.exports.middleware = (config = {}) ->
  (req, res, next) ->
    if req.query.sessid then sessid = req.query.sessid
    else if auth = req.get("authorization") then [header, sessid] = auth.match(/^token (\S+)$/i)
    
    if sessid
      sessions.loadSession sessid, (err, session) ->
        return next(err) if err
        return next() unless session
        
        unless 0 > badSessions.indexOf(sessid)
          console.log "[SPAM] Filtering out spam for sessid: #{sessid}"
          return next(new errors.NotFound) 
  
        req.currentSession = session
        req.currentUser = session.user if session.user
        
        next()
    else
      next()