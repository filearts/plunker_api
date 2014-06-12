mongoose = require("mongoose")
memoize = require("memoize")

{Query} = mongoose

# Add a pagination method to mongoose to simplify this repetitive stuff
Query::paginate = (page, limit, cb) ->
  page = Math.max(1, parseInt(page, 10))
  limit = Math.max(4, Math.min(12, parseInt(limit, 10))) # [4, 10]
  query = @
  countRecords = memoize @model.count.bind(@model),
    expire: 1000 * 60 # One minute
  
  query.skip(page * limit - limit).limit(limit).exec (err, docs) ->
    if err then return cb(err, null, null)
    countRecords query._conditions, (err, count) ->
      if err then return cb(err, null, null)
      cb(null, docs, count, Math.ceil(count / limit), page)