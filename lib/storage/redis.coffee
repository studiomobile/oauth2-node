redis  = require 'redis'

token_key = (token) -> "oauth:token:#{token}"

module.exports = class OAuthRedisStorage extends require('../storage')
  constructor: ->
    super
    @client = @options.client || redis.createClient(@options.port, @options.host, @options)
    throw new Error "Please provide client for OAuthRedisStorage or port and host" unless @client

  persist_token: (token, data, done) ->
    key = token_key(token)
    json = JSON.stringify data
    if data.expire
      expire = Date.now() - data.expire
      @client.setex key, expire, json, (error) -> done(error, token)
    else
      @client.set key, json, (error) -> done(error, token)
    
  fetch_token: (token, done) ->
    @client.get token_key(token), (error, json) ->
      return done(error) if error || !json
      try
        done null, JSON.parse(json)
      catch err
        done err
