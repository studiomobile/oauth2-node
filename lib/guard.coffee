util = require './util'
Err  = require './error'

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

    @storage.save_token_data data, (error, token) ->
      return done?(error) if error
      done?(null, token)

  revoke_token: (token, done) ->
    @storage.delete_token_data token, done


  middleware: (options) ->
    options = @_effective options
    realm   = options.realm || "Server"
    scope   = util.normalize_scope options.scope
    storage = options.storage

    invalid_request    = new Err "Invalid request", code:'invalid_request', realm:realm, scope:scope, status:400
    invalid_token      = new Err "Invalid token", code:'invalid_token', realm:realm, scope:scope, status:401
    expired_token      = new Err "Expired token", code:'expired_token', realm:realm, scope:scope, status:401
    insufficient_scope = new Err "Insufficient scope", code:'insufficient_scope', realm:realm, scope:scope, status:403

    check_scope = (token_scope) ->
      token_scope = util.normalize_scope token_scope
      # TODO: implement
      true

    expired = (data) ->
      data.expire && data.expire < Date.now()

    (req, res, next) ->
      token = find_oauth_token req
      return next invalid_request unless token
      if req.oauth?.access_token == token
        return next insufficient_scope unless check_scope req.oauth.scope
      storage.get_token_data token, (err, data) ->
        return next invalid_token unless data?.user_id
        return next expired_token if expired data
        return next insufficient_scope unless check_scope data.scope
        req.oauth = data
        next()


find_oauth_token = (req) ->
  auth = req.headers['authorization']?.split(' ')
  (auth[1] if auth?[0] == 'OAuth') or
  (URL.parse(req.url, true).query?.access_token) or
  (req.session?.access_token)
