appengine = require('appengine')
express = require("express")
morgan = require("morgan")
nconf = require("nconf")
cors = require("cors")


# Set defaults in nconf
require "./configure"


validateSchema = require("./middleware/schema")
apiErrors = require("./errors")



app = module.exports = express()
apiUrl = nconf.get("url:api")
wwwUrl = nconf.get("url:www")


{Session} = require("./database")


errorHandler = (err, req, res, next) ->
  if err instanceof apiErrors.ApiError
    res.json err.httpCode, err.toJSON()
    console.log "[ERR]", err.toJSON()
  else next(err)

#allowedCorsOrigins = [nconf.get('url:www'), nconf.get('url:embed'), "http://plnkr.co"]
corsOptions =
  origin: true
  exposeHeaders: "Link"
  maxAge: 60
    

app.set "jsonp callback", true

app.use appengine.middleware.base
app.use morgan("short")
app.use require("./middleware/cors").middleware()
app.use express.bodyParser()
app.use require("./middleware/version").middleware()
app.use require("./middleware/nocache").middleware()
app.use require("./middleware/session").middleware(sessions: Session)
app.use app.router
app.use errorHandler
app.use express.errorHandler()



# Sessions
sessions = require "./resources/sessions"


# Users
users = require "./resources/users"


app.get "/_ah/start", (req, res) ->
  res.send(200, "OK")
app.get "/_ah/stop", (req, res) ->
  res.send(200, "OK")
  process.exit(0)
app.get "/_ah/health", (req, res) ->
  res.send(200, "OK")


app.get "/proxy.html", (req, res) ->
  res.send """
    <!DOCTYPE HTML>
    <script src="https://cdn.rawgit.com/jpillora/xdomain/0.7.3/dist/xdomain.min.js" master="#{wwwUrl}"></script>
  """



app.get "/sessions", sessions.findOrCreate
app.post "/sessions", sessions.create
app.get "/sessions/:id", sessions.read

app.post "/sessions/:id/user", sessions.withSession, sessions.setUser
app.del "/sessions/:id/user", sessions.withSession, sessions.unsetUser


# Make sure all non-user, non-session put/post requests have a session assigned
app.put "*", sessions.withCurrentSession
app.post "*", sessions.withCurrentSession



# Plunks
plunks = require "./resources/plunks"


app.get "/plunks", plunks.createListing (req, res) ->
  baseUrl: "#{apiUrl}/plunks"
  sort: "-updated_at"
  ignorePrivate: true
  onlyPublic: true
app.get "/plunks/trending", plunks.createListing (req, res) ->
  baseUrl: "#{apiUrl}/plunks/trending"
  sort: "-score -updated_at"
  ignorePrivate: true
  onlyPublic: true
app.get "/plunks/popular", plunks.createListing (req, res) ->
  baseUrl: "#{apiUrl}/plunks/popular"
  sort: "-thumbs -updated_at"
  ignorePrivate: true
  onlyPublic: true

app.get "/plunks/views", plunks.createListing (req, res) ->
  baseUrl: "#{apiUrl}/plunks/views"
  sort: "-views -updated_at"
  ignorePrivate: true
  onlyPublic: true

app.get "/plunks/forked", plunks.createListing (req, res) ->
  baseUrl: "#{apiUrl}/plunks/forked"
  sort: "-forked -updated_at"
  ignorePrivate: true
  onlyPublic: true


app.get "/plunks/remembered", users.withCurrentUser, plunks.createListing (req, res) ->
  sort: "-updated_at"
  ignorePrivate: true
  query: {rememberers: req.currentUser._id}
  baseUrl: "#{apiUrl}/users/#{req.params.login}/remembered"

app.post "/plunks", sessions.withCurrentSession, validateSchema(plunks.schema.create), plunks.create
app.get "/plunks/:id", plunks.withPlunk, plunks.read
app.post "/plunks/:id", sessions.withCurrentSession, validateSchema(plunks.schema.update), plunks.withPlunk, plunks.ownsPlunk, plunks.update
app.del "/plunks/:id", plunks.withPlunk, plunks.ownsPlunk, plunks.destroy

app.post "/plunks/:id/freeze", sessions.withCurrentSession, plunks.withPlunk, plunks.ownsPlunk, plunks.freeze
app.del "/plunks/:id/freeze", sessions.withCurrentSession, plunks.withPlunk, plunks.ownsPlunk, plunks.unfreeze

app.post "/plunks/:id/thumb", sessions.withCurrentSession, plunks.withPlunk, plunks.setThumbed
app.del "/plunks/:id/thumb", sessions.withCurrentSession, plunks.withPlunk, plunks.unsetThumbed

app.post "/plunks/:id/remembered", sessions.withCurrentSession, plunks.withPlunk, plunks.setRemembered
app.del "/plunks/:id/remembered", sessions.withCurrentSession, plunks.withPlunk, plunks.unsetRemembered

forkSchema = (req) ->
  if req.apiVersion is 0 then plunks.schema.create
  else if req.apiVersion is 1 then plunks.schema.fork

app.post "/plunks/:id/forks", sessions.withCurrentSession, validateSchema(forkSchema), plunks.withPlunk, plunks.fork
app.get "/plunks/:id/forks", plunks.createListing (req, res) ->
  query: {fork_of: req.params.id}
  baseUrl: "#{apiUrl}/plunk/#{req.params.id}/forks"
  sort: "-updated_at"
  ignorePrivate: true
  onlyPublic: true



#app.get "/templates", plunks.createListing (req, res) ->
  #query = type: "template"
  #
  #if taglist = req.query.taglist then query.tags = {$all: taglist.split(",")}
  #
  #baseUrl: "#{apiUrl}/templates"
  #query: query
  #sort: "-thumbs -updated_at"
  #onlyPublic: true




app.get "/users/:login", users.withUser, users.read

app.get "/users/:login/plunks", users.withUser, plunks.createListing (req, res) ->
  sort: "-updated_at"
  query: {user: req.user._id}
  baseUrl: "#{apiUrl}/users/#{req.params.login}/plunks"
  ignorePrivate: req.currentUser and req.currentUser.login == req.params.login
  onlyPublic: !req.currentUser or req.currentUser.login != req.params.login
app.get "/users/:login/plunks/tagged/:tag", users.withUser, plunks.createListing (req, res) ->
  sort: "-updated_at"
  query: {user: req.user._id, tags: req.params.tag}
  baseUrl: "#{apiUrl}/users/#{req.params.login}/plunks/tagged/#{req.params.tag}"
  ignorePrivate: req.currentUser and req.currentUser.login == req.params.login
  onlyPublic: !req.currentUser or req.currentUser.login != req.params.login
app.get "/users/:login/thumbed", users.withUser, plunks.createListing (req, res) ->
  sort: "-updated_at"
  query: {voters: req.user._id}
  baseUrl: "#{apiUrl}/users/#{req.params.login}/thumbed"
  ignorePrivate: req.currentUser and req.currentUser.login == req.params.login
  onlyPublic: !req.currentUser or req.currentUser.login != req.params.login
app.get "/users/:login/remembered", users.withUser, plunks.createListing (req, res) ->
  sort: "-updated_at"
  query: {rememberers: req.user._id}
  baseUrl: "#{apiUrl}/users/#{req.params.login}/remembered"
  ignorePrivate: req.currentUser and req.currentUser.login == req.params.login
  onlyPublic: !req.currentUser or req.currentUser.login != req.params.login

###

# Comments
comments = require "./resources/comments"


app.post "/plunks/:id/comments", comments.create
app.get "/comments/:id", comments.read
app.post "/comments/:id", comments.update
app.del "/comments/:id", comments.destroy
docker -d --tlsverify --tlscacert=~/.docker/localhost/ca.pem --tlscert=~/.docker/localhost/server-cert.pem --tlskey=~/.docker/localhost/server-key.pem -H=localhost:2376
###

# Catalogue
packages = require "./resources/packages"

app.get "/catalogue/packages", packages.createListing (req, res) ->
  if q = req.param("query") then query: name: $regex: "^#{q}"
  else {}
  
#app.post "/catalogue/packages", validateSchema(packages.schema.create), packages.create
app.post "/catalogue/packages", validateSchema(packages.schema.create), users.withCurrentUser, packages.create
app.get "/catalogue/packages/:name", packages.withPackage, packages.read
app.post "/catalogue/packages/:name", validateSchema(packages.schema.update), users.withCurrentUser, packages.withPackage, packages.update
app.post "/catalogue/packages/:name/bump", users.withCurrentUser, packages.withPackage, packages.bump
app.del "/catalogue/packages/:name", packages.withOwnPackage, packages.destroy

app.post "/catalogue/packages/:name/maintainers", packages.withOwnPackage, packages.addMaintainer
app.del "/catalogue/packages/:name/maintainers", packages.withOwnPackage, packages.removeMaintainer

app.post "/catalogue/packages/:name/versions", validateSchema(packages.schema.versions.create), users.withCurrentUser, packages.withPackage, packages.versions.create
#app.get "/catalogue/packages/:name/versions/:semver", packages.withPackage, packages.readVersion
app.post "/catalogue/packages/:name/versions/:semver", validateSchema(packages.schema.versions.update), users.withCurrentUser, packages.withPackage, packages.versions.update
app.del "/catalogue/packages/:name/versions/:semver", packages.withOwnPackage, packages.versions.destroy

# Tags
tags = require "./resources/tags"

app.get "/tags", tags.list
app.get "/tags/:taglist", plunks.createListing (req, res) ->
  taglist = req.params.taglist.split(",")
  
  return res.json [] unless taglist.length
  
  query: if taglist.length > 1 then {tags: {$all: taglist}} else {tags: taglist[0]}
  baseUrl: "#{apiUrl}/tags/#{req.params.taglist}"
  sort: "-score -updated_at"

#app.get "/robots.txt", (req, res, next) ->
#  res.send """
#    User-Agent: *
#    Disallow: /
#  """

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