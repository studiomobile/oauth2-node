util = require './util'

module.exports = class Storage extends require('./options')
  constructor: ->
    super
  
  issue_token: (user_id, options, done) ->
    if typeof options == 'function'
      done = options
      options = {}
    token = util.gen_token()
    data =
      user_id: user_id
      scope: util.normalize_scope(options?.scope).join(',')
      expire: util.normalize_expire(options?.expire)
    @persist_token token, data, (error, data) ->
      return done?(error) if error
      done?(null, token)
