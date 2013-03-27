PackageVersionSchema = new Schema
  semver: String
  scripts: [String]
  styles: [String]

PackageSchema = new Schema
  name: { type: String, match: /^[-_.a-z0-9]+$/i, index: true, unique: true }
  description: { type: String }
  homepage: String
  keywords: [{type: String, index: true}]
  versions: [PackageVersionSchema]
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