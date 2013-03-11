Q       = require 'querystring'
URL     = require 'url'
request = require 'request'


module.exports = class Strategy extends require('./strategy')

  constructor: ->
    super

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
      done null, dialogUrl, {request_token:tokenData.oauth_token, request_token_secret:tokenData.oauth_token_secret}


  fetchAccessToken: (verifier, dialog, done) ->
    oauth =
      consumer_key: @get 'clientKey'
      consumer_secret: @get 'clientSecret'
      verifier:verifier
      token:dialog.request_token
      token_secret:dialog.request_token_secret
    request.post url:URL.format(@url 'token'), oauth:oauth, (error, response, body) ->
      return done error if error
      tokenData = Q.parse body
      done null, access_token:tokenData.oauth_token, access_token_secret:tokenData.oauth_token_secret


  fetchProtectedResource: (name, tokenData, done) ->
    useJson = if @get('useJson') == false then false else true
    request url:@url(name), oauth:@prepareOAuth(tokenData), json:useJson, (error, resp, data) -> done error, data


  prepareOAuth: (tokenData) ->
    consumer_key: @get 'clientKey'
    consumer_secret: @get 'clientSecret'
    token: tokenData.access_token
    token_secret: tokenData.access_token_secret
