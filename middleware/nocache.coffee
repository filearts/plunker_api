module.exports.middleware = (config = {}) ->
  (req, res, next) ->
    res.set
      "Cache-Control": "no-cache"
      "Expires": 0
    
    next()