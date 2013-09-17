module.exports = (schema, options = {}) ->
  schema.add updated_at: Date
  schema.pre "save", (next) ->
    @updated_at = Date.now()
    next()
  
  if options.index then schema.path("updated_at").index(options.index)