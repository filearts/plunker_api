mongoose = require("mongoose")
nconf = require("nconf")
mime = require("mime")
genid = require("genid")
url = require("url")


apiUrl = nconf.get('url:api')
wwwUrl = nconf.get('url:www')
runUrl = nconf.get('url:run')

plunkerDb = mongoose.createConnection nconf.get("mongodb:uri")
plunkerDbTimeout = setTimeout(errorConnecting, 1000 * 30)

errorConnecting = ->
  console.error "Error connecting to mongodb"
  process.exit(1)
  
plunkerDb.on "open", -> clearTimeout(plunkerDbTimeout)



# Enable Query::paginate
require "./plugins/paginate"

      
      
module.exports =
  Session: plunkerDb.model "Session", require("./schema/session").SessionSchema
  User: plunkerDb.model "User", require("./schema/user").UserSchema
  Plunk: plunkerDb.model "Plunk", require("./schema/plunk").PlunkSchema
  Package:plunkerDb.model "Package", require("./schema/package").PackageSchema


