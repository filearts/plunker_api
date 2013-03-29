module.exports.middleware = (config = {}) ->
  (req, res, next) ->
    
    req.apiVersion = (if v = req.param("api") then parseInt(v, 10) else 0)
    
    next()