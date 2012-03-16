module.exports = class OAuth2Error extends Error
  constructor: (@message, options) ->
    @name = 'OAuth2Error'
    @code = options.code if options?.code
    @realm  = options.realm if options?.realm
    @reason = options.reason if options?.reason
    @scope  = options.scope if options?.scope
    @status = options.status if options?.status
