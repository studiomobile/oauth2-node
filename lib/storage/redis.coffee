crypto = require 'crypto'

gen_token = -> crypto.createHash('sha512').update(crypto.randomBytes(128)).digest('base64')
token_key = (token) -> "oauth:token:#{token}"

module.exports = class Storage extends require('../storage')
  constructor: ->
    super
    @._accessor 'client'
    throw new Error "Please provide 'client' for RedisStorage" unless @client

  save_token_data: (data, done) ->
    token = gen_token()
    key = token_key token
    json = JSON.stringify data
    if data.expire or data.expire_at
      expire = data.expire or (data.expire_at - Date.now())
      @client.setex key, expire, json, (error) -> done(error, token)
    else
      @client.set key, json, (error) -> done(error, token)
    
  get_token_data: (token, done) ->
    @client.get token_key(token), (error, json) ->
      return done error or "Invalid token" if error or !json
      try
        done null, JSON.parse(json)
      catch error
        done error

  delete_token_data: (token, done) ->
    @client.del token_key(token), done
