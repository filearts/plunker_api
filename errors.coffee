exports.ApiError = class ApiError extends Error
  
createErrorClass = (name, classOptions = {}) ->
  
  classOptions.message ||= ""
  
  class extends ApiError
    @::[prop] = val for prop, val of classOptions
  
    constructor: (@message = classOptions.message, options = {}) ->
      Error.call(@)
      Error.captureStackTrace(@, arguments.callee)
      
      @name = options.name or name
      
      @[prop] = val for prop, val of options
      

errorTypes =
  DatabaseError:
    message: "Database error"
    httpCode: 400
  NotFound:
    message: "Not Found"
    httpCode: 404


exports[name] = createErrorClass(name, errDef.message, errDef) for name, errDef of errorTypes
  