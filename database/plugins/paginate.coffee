mongoose = require("mongoose")

{Query} = mongoose

# Add a pagination method to mongoose to simplify this repetitive stuff
Query::paginate = (page, limit, cb) ->
  page = Math.max(1, parseInt(page, 10))
  limit = Math.max(4, Math.min(12, parseInt(limit, 10))) # [4, 10]
  query = @
  model = @model
  
  query.skip(page * limit - limit).limit(limit).exec (err, docs) ->
    if err then return cb(err, null, null)
    model.count query._conditions, (err, count) ->
      if err then return cb(err, null, null)
      cb(null, docs, count, Math.ceil(count / limit), page)