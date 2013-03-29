express = require("express")
nconf = require("nconf")
cors = require("cors")

# Set defaults in nconf
require "./configure"


validateSchema = require("./middleware/schema")
apiErrors = require("./errors")



app = module.exports = express()
apiUrl = nconf.get("api:url")




errorHandler = (err, req, res, next) ->
  if err instanceof apiErrors.ApiError
    res.json err.httpCode, err.toJSON()
  else next(err)


app.set "jsonp callback", true

app.use cors()
app.use express.bodyParser()
app.use require("./middleware/version").middleware()
app.use require("./middleware/nocache").middleware()
app.use require("./middleware/session").middleware(sessions: Session)
app.use app.router
app.use errorHandler
app.use express.errorHandler()



# Sessions
sessions = require "./resources/sessions"


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

app.post "/plunks", validateSchema(plunks.schema.create), plunks.create
app.get "/plunks/:id", plunks.withPlunk, plunks.read
app.post "/plunks/:id", validateSchema(plunks.schema.update), plunks.withPlunk, plunks.ownsPlunk, plunks.update
app.del "/plunks/:id", plunks.withPlunk, plunks.ownsPlunk, plunks.destroy

app.post "/plunks/:id/thumb", plunks.withPlunk, plunks.setThumbed
app.del "/plunks/:id/thumb", plunks.withPlunk, plunks.unsetThumbed

forkSchema = (req) ->
  if req.apiVersion is 0 then plunks.schema.create
  else if req.apiVersion is 1 then plunks.schema.fork

app.post "/plunks/:id/forks", validateSchema(forkSchema), plunks.withPlunk, plunks.fork
app.get "/plunks/:id/forks", plunks.createListing (req, res) ->
  query: {fork_of: req.params.id}
  baseUrl: "#{apiUrl}/plunk/#{req.params.id}/forks"
  sort: "-updated_at"


# Users
users = require "./resources/users"

app.get "/users/:login", users.withUser, users.read

app.get "/users/:login/plunks", users.withUser, plunks.createListing (req, res) ->
  query: {user: req.user._id}
  baseUrl: "#{apiUrl}/users/#{req.params.login}/plunks"
app.get "/users/:login/thumbed", users.withUser, plunks.createListing (req, res) ->
  query: {voters: req.user._id}
  baseUrl: "#{apiUrl}/users/#{req.params.login}/thumbed"

###

# Comments
comments = require "./resources/comments"


app.post "/plunks/:id/comments", comments.create
app.get "/comments/:id", comments.read
app.post "/comments/:id", comments.update
app.del "/comments/:id", comments.destroy

###

app.get "/robots.txt", (req, res, next) ->
  res.send """
    User-Agent: *
    Disallow: /
  """

app.get "/favicon.ico", (req, res, next) ->
  console.log "Requesting favicon.ico"
  res.send("")

app.all "*", (req, res, next) -> next(new apiErrors.NotFound)

Session = require("./database").Session

PRUNE_FREQUENCY = 1000 * 60 * 60 * 6 # Prune the sessions every 6 hours

pruneSessions = ->
  console.log "Pruning sessions"
  Session.prune()

setInterval pruneSessions, PRUNE_FREQUENCY