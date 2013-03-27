mongoose = require("mongoose")


{Schema, Document, Query} = mongoose
{ObjectId, Mixed} = Schema.Types


exports.UserSchema = new Schema
  login: { type: String, index: true }
  gravatar_id: String
  service_id: { type: String, index: { unique: true } }
  profile: {}