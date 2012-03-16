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
      token = util.find_oauth_token req
      return next invalid_request unless token
      if req.oauth?.access_token == token
        return next insufficient_scope unless check_scope req.oauth.scope
      storage.fetch_token_data token, (err, data) ->
        return next invalid_token unless data?.user_id
        return next expired_token if expired data
        return next insufficient_scope unless check_scope data.scope
        req.oauth = data
        next()

Guard.errorHandler = (error, req, res, next) ->
  return next error unless error instanceof Err
  res.status = error.status or 401
  if req.accepts 'application/json'
    res.json error:error
  else
    scope_msg = error.scope.map((scope) -> "'#{scope}'").join(' ')
    res.header 'WWW-Authenticate', "OAuth realm='#{error.realm}', error='#{error.code}' #{scope_msg}"
    res.end error.message
