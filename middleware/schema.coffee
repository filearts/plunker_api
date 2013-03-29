_ = require("underscore")._
apiErrors = require("../errors")

module.exports = (schema) ->
  (req, res, next) ->
    schema = schema(req) if _.isFunction(schema)
    schema.validate req.body, (err, json) ->
      if err then next(new apiErrors.InvalidBody(err))
      else next()