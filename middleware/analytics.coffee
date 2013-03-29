analytics = require("analytics-node")
_ = require("underscore")._

module.exports = (config = {}) ->
  (req, res, next) ->
    req.track = (event, properties = {}) ->
      
    next()
  req.analytics = {}
  
  req.analytics.userId = req.currentUser._id if req.currentUser
  
  next()
    