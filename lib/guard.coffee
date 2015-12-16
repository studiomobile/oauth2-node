URL    = require 'url'
crypto = require 'crypto'
util   = require './util'
Err    = require './error'

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

    gen_token = -> crypto.createHash('sha512').update(crypto.randomBytes(128)).digest('base64')

    data =
      user_id: user_id
      key: gen_token()
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
    debug   = options.debug || { warn:(->) }

    invalid_request    = new Err "Invalid request", code:'invalid_request', realm:realm, scope:scope, status:400
    invalid_token      = new Err "Invalid token", code:'invalid_token', realm:realm, scope:scope, status:401
    expired_token      = new Err "Expired token", code:'expired_token', realm:realm, scope:scope, status:401
    insufficient_scope = new Err "Insufficient scope", code:'insufficient_scope', realm:realm, scope:scope, status:403

    check_scope = (token_scope) ->
      token_scope = util.normalize_scope token_scope
      # TODO: implement
      true

    expired = (data) ->
      data.expire < Date.now() if data.expire

    (req, res, next) ->
      token = Guard.findOAuthToken req
      debug.warn "Verifying oauth token from client", req.ip, token
      return next invalid_request unless token
      if req.oauth?.access_token == token
        return next insufficient_scope unless check_scope req.oauth.scope
      storage.get_token_data token, (err, data) ->
        debug.warn "Got token data from client", req.ip, data
        return next invalid_token unless data?.user_id
        return next expired_token if expired data
        return next insufficient_scope unless check_scope data.scope
        req.oauth = data
        debug.warn "Token data from client is valid", req.ip
        next()


Guard.findOAuthToken = (req) ->
  auth = req.headers['authorization']?.split(' ')
  (auth[1] if auth?[0] == 'OAuth') or
  (URL.parse(req.url, true).query?.access_token) or
  (req.session?.access_token)
