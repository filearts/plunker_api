module.exports = (schema) ->
  (req, res, next) ->
    schema.validate req.body, (err, json) ->
      if err then res.json(err, 400)
      else next()