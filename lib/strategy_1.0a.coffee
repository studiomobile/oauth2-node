Q       = require 'querystring'
URL     = require 'url'
request = require 'request'


module.exports = class Strategy extends require('./strategy')
  constructor: ->
    super
    @version = '1.0a'


  prepareDialogUrl: (options, done) ->
    oauth =
      consumer_key: @get 'clientKey'
      consumer_secret: @get 'clientSecret'
      callback: URL.format options.redirect
    request.post url:URL.format(@url 'request'), oauth:oauth, (error, response, body) =>
      return error if error
      delete oauth.callback
      tokenData = Q.parse body
      dialogUrl = @url 'dialog'
      dialogUrl.query or= {}
      dialogUrl.query.oauth_token = tokenData.oauth_token
      done null, dialogUrl, tokenData


  fetchAccessToken: (verifier, tokenData, done) ->
    oauth = @prepareOAuth tokenData
    oauth.verifier = verifier
    request.post url:URL.format(@url 'token'), oauth:oauth, (error, response, body) ->
      return done error if error
      done null, Q.parse body


  fetchProtectedResource: (name, tokenData, done) ->
    useJson = if @get('useJson') == false then false else true
    request url:URL.format(@url name), oauth:@prepareOAuth(tokenData), json:useJson, (error, resp, data) -> done error, data


  prepareOAuth: (tokenData) ->
    consumer_key: @get 'clientKey'
    consumer_secret: @get 'clientSecret'
    token: tokenData.oauth_token
    token_secret: tokenData.oauth_token_secret
