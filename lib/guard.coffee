util = require './util'

module.exports = class Guard extends require('./options')
  constructor: ->
    super
    @._accessor 'storage'
    throw new Error("Please provide 'storage' for OAuth Guard") unless @storage

  issue_token: (user_id, options, done) ->
    if typeof options == 'function'
      done = options
      options = {}

    options = @_effective options

    data =
      user_id: user_id
      scope: util.normalize_scope(options.scope).join(',')
      expire: util.normalize_expire(options.expire) if options.expire
      expire_at: util.normalize_expire(options.expire_at) if options.expire_at

    @storage.persist_token_data data, (error, token) ->
      return done?(error) if error
      done?(null, token)

  revoke_token: (token, done) ->
    @storage.delete_token_data token, done


  middleware: (options) ->
    options = @_effective options
    realm   = options.realm || "Server"
    scope   = util.normalize_scope options.scope
    storage = storage

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

      storage.fetch_token_data token, (err, data) ->
        return invalid_token(res) if !data?.user_id
        return expired_token(res) if data.expire && data.expire < Date.now()
        return insufficient_scope(res) if !check_scope(data.scope)
        data.access_token = token
        req.oauth = data
        next()
