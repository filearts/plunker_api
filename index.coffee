express = require("express")
nconf = require("nconf")
cors = require("cors")


# Set defaults in nconf
require "./configure"



Session = require("./database").Session


app = express()



app.set "jsonp callback", true

app.use cors()
app.use express.bodyParser()
app.use require("./middleware/session").middleware(sessions: Session)
app.use app.router
app.use errorHandler



# Sessions
sessions = require "../endpoints/sessions"


app.get "/sessions", sessions.readOrCreate
app.post "/sessions", sessions.create
app.get "/sessions/:id", sessions.read

app.post "/sessions/:id/user", sessions.setUser
app.del "/sessions/:id/user", sessions.unsetUser


# Plunks
plunks = require "../endpoints/plunks"


app.get "/plunks", plunks.createListing()
app.get "/plunks/trending", plunks.createListing
  baseUrl: "#{apiUrl}/plunks/trending"
  sort: "-score -updated_at"
app.get "/plunks/popular", plunks.createListing
  baseUrl: "#{apiUrl}/plunks/popular"
  sort: "-thumbs -updated_at"

app.post "/plunks", plunks.create
app.get "/plunks/:id", plunks.read
app.post "/plunks/:id", plunks.update
app.del "/plunks/:id", plunks.destroy

app.post "/plunks/:id/thumb", plunks.setThumbed
app.del "/plunks/:id/thumb", plunks.unsetThumbed

app.post "/plunks/:id/forks", plunks.fork
app.get "/plunks/:id/forks", plunks.createListing
  query: {fork_of: req.params.id}
  baseUrl: "#{apiUrl}/plunk/#{req.params.id}/forks"
  sort: "-updated_at"
  
app.get "/users/:login/plunks", users.middleware.read, plunks.createListing
  query: {user: req.found_user._id}
  baseUrl: "#{apiUrl}/users/#{req.params.username}/plunks"
app.get "/users/:login/thumbed", users.middleware.read, plunks.createListing
  query: {voters: req.found_user._id}
  baseUrl: "#{apiUrl}/users/#{req.params.username}/thumbed"


# Comments
comments = require "../endpoints/comments"


app.post "/plunks/:id/comments", comments.create
app.get "/comments/:id", comments.read
app.post "/comments/:id", comments.update
app.del "/comments/:id", comments.destroy


# Users
users = require "../endpoints/users"


app.get "/users/:login", users.read



app.all "*", (req, res, next) -> next(new errors.NotFound)


errorHandler = (err, req, res, next) ->
  if err instanceof errors.ApiError then res.json err.httpCode,
    message: err.message



PRUNE_FREQUENCY = 1000 * 60 * 60 * 6 # Prune the sessions every 6 hours
SCORE_INCREMENT = 1000 * 60 * 60 * 6 # Each vote bumps the plunk forward 6 hours

pruneSessions = ->
  console.log "Pruning sessions"
  Session.prune()

setInterval pruneSessions, PRUNE_FREQUENCY
pruneSessions()




module.exports = app