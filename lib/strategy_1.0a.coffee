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
    request.post uri:URL.format(@url 'request'), oauth:oauth, (error, resp, body) =>
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
    request.post uri:URL.format(@url 'token'), oauth:oauth, (error, resp, body) ->
      return done error if error
      done null, Q.parse body


  fetchProtectedResource: (url, tokenData, done) ->
    useJson = if @get('useJson') == false then false else true
    request uri:URL.format(url), oauth:@prepareOAuth(tokenData), json:useJson, (error, resp, data) -> done error, data, resp


  postProtectedResource: (url, tokenData, done) ->
    useJson = if @get('useJson') == false then false else true
    query = url.query
    delete url.query
    request.post uri:URL.format(url), form:query, oauth:@prepareOAuth(tokenData), json:useJson, (error, resp, data) -> done error, data, resp


  prepareOAuth: (tokenData) ->
    consumer_key: @get 'clientKey'
    consumer_secret: @get 'clientSecret'
    token: tokenData.oauth_token
    token_secret: tokenData.oauth_token_secret
