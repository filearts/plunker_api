nconf = require("nconf")
_ = require("lodash")

module.exports.middleware = (config = {}) ->
  
  valid = [nconf.get('url:www'), nconf.get('url:embed'), "http://plnkr.co"]
  
  (req, res, next) ->
    # Just send the headers all the time. That way we won't miss the right request ;-)
    # Other CORS middleware just wouldn't work for me
    # TODO: Minimize these headers to only those needed at the right time
    
    res.header("Access-Control-Allow-Origin", if req.headers.origin in valid then req.headers.origin else "*")
    res.header("Access-Control-Allow-Methods", "OPTIONS,GET,PUT,POST,DELETE")
  
    if requestHeaders = req.headers['access-control-request-headers']
      allowHeaders = _(requestHeaders.split(",")).invoke("trim").invoke("toLowerCase").sort().value().join(", ")
      res.header("Access-Control-Allow-Headers", allowHeaders)
      
    res.header("Access-Control-Expose-Headers", "Link")
    res.header("Access-Control-Max-Age", "60")

    if "OPTIONS" == req.method then res.send(200)
    else next()