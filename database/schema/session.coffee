mongoose = require("mongoose")
nconf = require("nconf")
genid = require("genid")

apiUrl = nconf.get("url:api")


{Schema, Document, Query} = mongoose
{ObjectId, Mixed} = Schema.Types


TokenSchema = new Schema
  _id: { type: String, ref: "Plunk" }
  token: { type: String }


SessionSchema = new Schema
  user:
    type: Schema.ObjectId
    ref: "User"
  user_info: {}
  last_access: { type: Date, index: true, 'default': Date.now }
  public_id: { type: String, 'default': genid }
  auth: {}
  keychain: [TokenSchema]

SessionSchema.virtual("url").get -> apiUrl + "/sessions/#{@_id}"
SessionSchema.virtual("user_url").get -> apiUrl + "/sessions/#{@_id}/user"
SessionSchema.virtual("age").get -> Date.now() - @last_access

SessionSchema.set "toJSON",
  virtuals: true
  getters: true
  transform: (session, json, options) ->
    json.id = json._id
    
    json.user = json.user_info if json.user_info
    
    delete json.user_info
    delete json._id
    delete json.__v
    
    json
exports.SessionSchema = SessionSchema