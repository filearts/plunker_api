exports.ApiError = class ApiError extends Error
  
createErrorClass = (name, classOptions = {}) ->
  
  classOptions.message ||= "Unknown error"
  classOptions.httpCode ||= 500
  classOptions.initialize ||= (message, options = {}) ->
    @message = message if message
    @[prop] = val for prop, val of options
  classOptions.toJSON ||= ->
    error: @message

    
  
  class extends ApiError
    @::[prop] = val for prop, val of classOptions
    
    constructor: ->
      Error.call(@)
      Error.captureStackTrace(@, arguments.callee)
      
      @name = name
      
      @initialize(arguments...)
      

      
errorTypes =
  ResourceExists:
    httpCode: 400
    message: "Resource exists"
  DatabaseError:
    httpCode: 400
    message: "Database error"
    initialize: (err) -> console.error("[ERR] #{@message}", err)
  InvalidBody:
    httpCode: 400
    message: "Invalid payload"
    initialize: (err) -> @invalid = err.message
    toJSON: ->
      message: @message
      invalid: @invalid
  NotFound:
    message: "Not Found"
    httpCode: 404
  PermissionDenied:
    message: "Permission denied"
    httpCode: 404
  ImpossibleError:
    message: "Impossibru"
    initialize: (err) -> console.error("[ERR] #{@message}", err)

exports[name] = createErrorClass(name, errDef) for name, errDef of errorTypes
  