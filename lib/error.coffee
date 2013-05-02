module.exports = class OAuth2Error extends Error
  constructor: (@message, options) ->
    @name = 'OAuth2Error'
    @code = options.code if options?.code
    @realm  = options.realm if options?.realm
    @reason = options.reason if options?.reason
    @scope  = options.scope if options?.scope
    @status = options.status if options?.status


OAuth2Error.Unauthorized = (message, options = {}) ->
  options.reason = OAuth2Error.Unauthorized.reason
  new OAuth2Error message, options

OAuth2Error.Unauthorized.reason = 'Unauthorized'
