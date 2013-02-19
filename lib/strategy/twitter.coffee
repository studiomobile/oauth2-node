URL   = require 'url'
oauth = require 'oauth'

module.exports = class Strategy extends require('../strategy')
  constructor: ->
    super
    @version = '1.0a'
    @regUrl 'request', 'https://twitter.com/oauth/request_token'
    @regUrl 'dialog', 'https://twitter.com/oauth/authenticate'
    @regUrl 'token', 'https://twitter.com/oauth/access_token'
    @regUrl 'profile', 'http://api.twitter.com/1/account/verify_credentials.json'


  getOAuthClient: (requestUrl, tokenUrl, clientKey, clientSecret) ->
    @client = new oauth.OAuth(requestUrl, tokenUrl, clientKey, clientSecret, "1.0A", undefined, "HMAC-SHA1")


  parseProfile: (data, done) ->
    done null,
      provider: 'twitter'
      id: data.id
      username: data.screen_name
      displayName: data.name
      profileUrl: "https://twitter.com/#{data.screen_name}"


  fetchProfile: (oauth, done) ->
    profileUrl = URL.format @url('profile')
    @client.get profileUrl, oauth.access_token, oauth.access_token_secret, (error, data, response) =>
      return done error if error
      @json data, done, @parseProfile
