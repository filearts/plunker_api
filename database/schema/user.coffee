mongoose = require("mongoose")


{Schema, Document, Query} = mongoose
{ObjectId, Mixed} = Schema.Types


exports.UserSchema = UserSchema = new Schema
  login: { type: String, index: true }
  gravatar_id: String
  service_id: { type: String, index: { unique: true } }

UserSchema.virtual("created_at").get -> new Date(parseInt(@_id.toString().substring(0, 8), 16) * 1000)

UserSchema.set "toJSON",
  virtuals: true
  transform: (user, json, options) ->
    delete json._id
    delete json.__v
    delete json.id
    delete json.service_id
    
    json
