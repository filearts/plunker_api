mongoose = require("mongoose")
genid = require("genid")
nconf = require("nconf")
mime = require("mime")

{Schema, Document, Query} = mongoose
{ObjectId, Mixed} = Schema.Types

wwwUrl = nconf.get("url:www")
apiUrl = nconf.get("url:api")
runUrl = nconf.get("url:run")


PlunkFileSchema = new Schema
  filename: String
  content: String
  
PlunkFileSchema.virtual("mime").get -> mime.lookup(@filename, "text/plain")
  
PlunkVoteSchema = new Schema
  user: { type: Schema.ObjectId, ref: "User" }
  created_at: { type: Date, 'default': Date.now }

PlunkChangeSchema = new Schema
  fn: String # Current/new filename
  pn: String # Previous filename
  pl: String # Payload (contents / diff)

PlunkHistorySchema = new Schema
  event: { type: String, 'enum': ["create", "update", "fork"] }
  user: { type: Schema.ObjectId, ref: "User" }
  changes: [PlunkChangeSchema]
  
PlunkHistorySchema.virtual("created_at").get -> new Date(parseInt(@_id.toString().substring(0, 8), 16) * 1000)

PlunkSchema = new Schema
  _id: { type: String, index: true }
  description: String
  score: { type: Number, 'default': Date.now }
  thumbs: { type: Number, 'default': 0 }
  created_at: { type: Date, 'default': Date.now }
  updated_at: { type: Date, 'default': Date.now }
  token: { type: String, 'default': genid.bind(null, 16) }
  'private': { type: Boolean, 'default': false }
  template: { type: Boolean, 'default': false }
  source: {}
  files: [PlunkFileSchema]
  user: { type: Schema.ObjectId, ref: "User", index: true }
  comments: { type: Number, 'default': 0 }
  fork_of: { type: String, ref: "Plunk", index: true }
  forks: [{ type: String, ref: "Plunk", index: true }]
  tags: [{ type: String, index: true}]
  voters: [{ type: Schema.ObjectId, ref: "Users", index: true }]
  rememberers: [{ type: Schema.ObjectId, ref: "Users", index: true }]
  history: [PlunkHistorySchema]
  views: { type: Number, 'default': 0 }
  forked: { type: Number, 'default': 0 }
  
PlunkSchema.index(score: -1, updated_at: -1)
PlunkSchema.index(thumbs: -1, updated_at: -1)
PlunkSchema.index(views: -1, updated_at: -1)
PlunkSchema.index(forked: -1, updated_at: -1)

PlunkSchema.virtual("url").get -> apiUrl + "/plunks/#{@_id}"
PlunkSchema.virtual("raw_url").get -> runUrl + "/plunks/#{@_id}/"
PlunkSchema.virtual("comments_url").get -> wwwUrl + "/#{@_id}/comments"

exports.PlunkSchema = PlunkSchema