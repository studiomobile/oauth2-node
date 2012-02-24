util = require './util'

module.exports = class Guard extends require('./options')
  constructor: ->
    super
  
  middleware: ->
    realm   = @options.realm || "Server"
    scope   = util.normalize_scope @options.scope
    storage = @options.storage
    throw new Error("Please provide storage for OAuth Guard") unless storage
    throw new Error("OAuth Guard storage should have fetch_token method") unless typeof storage.fetch_token == 'function'

    scope_msg = scope.map((scope) -> "'#{scope}'").join(' ')

    check_scope = (token_scope) ->
      token_scope = util.normalize_scope token_scope
      # TODO: implement
      true

    error = (res, code, error) ->
      res.statusCode = code
      res.header 'WWW-Authenticate', "OAuth realm='#{realm}', error='#{error}' #{scope_msg}"
      res.end 'Unauthorized'

    invalid_request    = (res) -> error res, 400, 'invalid_request'
    invalid_token      = (res) -> error res, 401, 'invalid_token'
    expired_token      = (res) -> error res, 401, 'expired_token'
    insufficient_scope = (res) -> error res, 403, 'insufficient_scope'

    (req, res, next) ->
      token = util.find_oauth_token req
      return invalid_request(res) unless token
      return insufficient_scope(res) if req.oauth?.access_token == token && !check_scope(req.oauth.scope)

      storage.fetch_token token, (err, data) ->
        return invalid_token(res) if !data?.user_id
        return expired_token(res) if data.expire && data.expire < Date.now()
        return insufficient_scope(res) if !check_scope(data.scope)
        data.access_token = token
        req.oauth = data
        next()
