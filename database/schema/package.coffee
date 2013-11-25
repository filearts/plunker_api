mongoose = require("mongoose")


{Schema, Document, Query} = mongoose
{ObjectId, Mixed} = Schema.Types

PackageDependencySchema = new Schema
  name: String
  range: String

PackageVersionSchema = new Schema
  semver: String
  unstable: { type: Boolean, default: false }
  scripts: [String]
  styles: [String]
  dependencies: [PackageDependencySchema]

PackageSchema = new Schema
  name: { type: String, match: /^[-_.a-z0-9]+$/i, index: true, unique: true }
  created_at: { type: Date, default: Date.now() }
  versionCount: { type: Number, default: 0 }
  description: { type: String }
  homepage: String
  documentation: String
  keywords: [{type: String, index: true}]
  versions: [PackageVersionSchema]
  categories: [String]
  bumps: { type: Number, default: 0, index: true }
  maintainers: [{ type: String, index: true }]

###
PackageSchema.index {
  name: "text"
  description: "text"
  keywords: "text"
}, {
  name: "typeahead"
  weights:
    name: 3
    description: 1
    keywords: 2
}
###

exports.PackageSchema = PackageSchema