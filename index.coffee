express = require("express")
nconf = require("nconf")
cors = require("cors")

#memwatch = require("memwatch");

#memwatch.on "leak", (d) -> console.log "[LEAK]", d

# Set defaults in nconf
require "./configure"


validateSchema = require("./middleware/schema")
apiErrors = require("./errors")



app = module.exports = express()
apiUrl = nconf.get("url:api")


{Session} = require("./database")


errorHandler = (err, req, res, next) ->
  if err instanceof apiErrors.ApiError
    res.json err.httpCode, err.toJSON()
  else next(err)


app.set "jsonp callback", true

app.use require("./middleware/cors").middleware()
app.use express.bodyParser()
app.use require("./middleware/version").middleware()
app.use require("./middleware/nocache").middleware()
app.use require("./middleware/session").middleware(sessions: Session)
app.use app.router
app.use errorHandler
app.use express.errorHandler()

###
hd = null

app.get "/debug/start", (req, res, next) ->
  if hd then res.send 400, "Heap diff in progress"
  else
    hd = new memwatch.HeapDiff
    res.send 200, "Heap diff started"

app.get "/debug/end", (req, res, next) ->
  if hd then res.json hd.end()
  else res.send 400, "Heap diff not in progress"
  
  hd = null
  
app.get "/debug/gc", (req, res, next) ->
  memwatch.gc()
  
  res.send "Garbage collected"
###

# Sessions
sessions = require "./resources/sessions"

# Users
users = require "./resources/users"


app.get "/sessions", sessions.findOrCreate
app.post "/sessions", sessions.create
app.get "/sessions/:id", sessions.read

app.post "/sessions/:id/user", sessions.withSession, sessions.setUser
app.del "/sessions/:id/user", sessions.withSession, sessions.unsetUser


# Plunks
plunks = require "./resources/plunks"


app.get "/plunks", plunks.createListing()
app.get "/plunks/trending", plunks.createListing (req, res) ->
  baseUrl: "#{apiUrl}/plunks/trending"
  sort: "-score -updated_at"
app.get "/plunks/popular", plunks.createListing (req, res) ->
  baseUrl: "#{apiUrl}/plunks/popular"
  sort: "-thumbs -updated_at"
app.get "/plunks/views", plunks.createListing (req, res) ->
  baseUrl: "#{apiUrl}/plunks/views"
  sort: "-views -updated_at"
app.get "/plunks/forked", plunks.createListing (req, res) ->
  baseUrl: "#{apiUrl}/plunks/forked"
  sort: "-forked -updated_at"

app.get "/plunks/remembered", users.withCurrentUser, plunks.createListing (req, res) ->
  sort: "-updated_at"
  ignorePrivate: true
  query: {rememberers: req.currentUser._id}
  baseUrl: "#{apiUrl}/users/#{req.params.login}/remembered"

app.post "/plunks", validateSchema(plunks.schema.create), plunks.create
app.get "/plunks/:id", plunks.withPlunk, plunks.read
app.post "/plunks/:id", validateSchema(plunks.schema.update), plunks.withPlunk, plunks.ownsPlunk, plunks.update
app.del "/plunks/:id", plunks.withPlunk, plunks.ownsPlunk, plunks.destroy

app.post "/plunks/:id/thumb", plunks.withPlunk, plunks.setThumbed
app.del "/plunks/:id/thumb", plunks.withPlunk, plunks.unsetThumbed

app.post "/plunks/:id/remembered", plunks.withPlunk, plunks.setRemembered
app.del "/plunks/:id/remembered", plunks.withPlunk, plunks.unsetRemembered

forkSchema = (req) ->
  if req.apiVersion is 0 then plunks.schema.create
  else if req.apiVersion is 1 then plunks.schema.fork

app.post "/plunks/:id/forks", validateSchema(forkSchema), plunks.withPlunk, plunks.fork
app.get "/plunks/:id/forks", plunks.createListing (req, res) ->
  query: {fork_of: req.params.id}
  baseUrl: "#{apiUrl}/plunk/#{req.params.id}/forks"
  sort: "-updated_at"



app.get "/users/:login", users.withUser, users.read

app.get "/users/:login/plunks", users.withUser, plunks.createListing (req, res) ->
  sort: "-updated_at"
  query: {user: req.user._id}
  baseUrl: "#{apiUrl}/users/#{req.params.login}/plunks"
app.get "/users/:login/thumbed", users.withUser, plunks.createListing (req, res) ->
  sort: "-updated_at"
  query: {voters: req.user._id}
  baseUrl: "#{apiUrl}/users/#{req.params.login}/thumbed"
app.get "/users/:login/remembered", users.withUser, plunks.createListing (req, res) ->
  sort: "-updated_at"
  query: {rememberers: req.user._id}
  baseUrl: "#{apiUrl}/users/#{req.params.login}/remembered"

###

# Comments
comments = require "./resources/comments"


app.post "/plunks/:id/comments", comments.create
app.get "/comments/:id", comments.read
app.post "/comments/:id", comments.update
app.del "/comments/:id", comments.destroy

###

# Catalogue
packages = require "./resources/packages"

app.get "/catalogue/typeahead", packages.createListing()
app.get "/catalogue/typeahead/:query", packages.createListing (req, res) ->
  if req.params.query then query: name: $regex: "^#{req.params.query}"
  else {}
  
app.get "/catalogue/packages", packages.createListing()

app.post "/catalogue/packages", validateSchema(packages.schema.create), users.withUser, packages.create
app.get "/catalogue/packages/:name", packages.withPackage, packages.read
app.post "/catalogue/packages/:name", validateSchema(packages.schema.update), packages.withOwnPackage, packages.update
app.post "/catalogue/packages/:name/bump", validateSchema(packages.schema.update), packages.withOwnPackage, packages.update
app.del "/catalogue/packages/:name", packages.withOwnPackage, packages.destroy

app.post "/catalogue/packages/:name/maintainers", packages.withOwnPackage, packages.addMaintainer
app.del "/catalogue/packages/:name/maintainers", packages.withOwnPackage, packages.removeMaintainer

app.post "/catalogue/packages/:name/versions/", validateSchema(packages.schema.versions.create), packages.withOwnPackage, packages.versions.create
#app.get "/catalogue/packages/:name/versions/:semver", packages.withPackage, packages.readVersion
app.post "/catalogue/packages/:name/versions/:semver", validateSchema(packages.schema.versions.update), packages.withOwnPackage, packages.versions.update
app.del "/catalogue/packages/:name/versions/:semver", packages.withOwnPackage, packages.versions.destroy

# Tags
tags = require "./resources/tags"

app.get "/tags", tags.list


app.get "/robots.txt", (req, res, next) ->
  res.send """
    User-Agent: *
    Disallow: /
  """

app.get "/favicon.ico", (req, res, next) ->
  res.send("")

app.all "*", (req, res, next) -> next(new apiErrors.NotFound)


PRUNE_FREQUENCY = 1000 * 60 * 60 * 6 # Prune the sessions every 6 hours

pruneSessions = ->
  console.log "[INFO] Pruning sessions"
  sessions.prune (err, numDocs) ->
    if err then console.log "[ERR] Pruning failed", err.message
    else console.log "[OK] Pruned #{numDocs} sessions"
  
  setTimeout pruneSessions, PRUNE_FREQUENCY

pruneSessions()