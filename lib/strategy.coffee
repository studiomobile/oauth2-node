_     = require 'underscore'
Q     = require 'querystring'
URL   = require 'url'
async = require 'async'
util  = require './util'

module.exports = class Strategy extends require('./options')
  constructor: ->
    super
    @scopeSeparator = ','
    @_urls = {}


  regUrl: (type, url) ->
    @_urls[type] = url

  url: (type, data) ->
    url = @_urls[type]
    @parseUrl url, data if url

  parseUrl: (url, data) ->
    return URL.parse url.replace(/\{\{(.+?)\}\}/g, ($0, $1) -> data[$1] || ''), true if _.isString url
    return url.call @, data if _.isFunction url
    url


  prepareDialogUrl: (options, done) ->
    url = @url 'dialog'
    query = url.query or= {}
    scope = options.scope or @get 'scope'
    query.scope = util.normalize_scope(scope).join @scopeSeparator
    query.display = options.display or @get 'display'
    query.client_id = @get 'clientID'
    query.response_type = 'code'
    query.redirect_uri = options.redirect
    done null, url


  fetchAccessToken: (code, dialog, done) ->
    url = @url 'token'
    query = url.query or= {}
    query.grant_type = 'authorization_code'
    query.client_id = @get 'clientID'
    query.client_secret = @get 'clientSecret'
    query.code = code
    query.redirect_uri = dialog.redirect
    util.perform_request url, (error, data) ->
      return done error if error
      done null, try
        JSON.parse data
      catch err
        Q.parse data


  fetchProtectedResource: (url, tokenData, done) ->
    useJson = if @get('useJson') == false then false else true
    util.perform_request url, (error, data, resp) ->
      return done error if error
      if useJson
        try
          data = JSON.parse data
        catch err
          return done err
      done null, data, resp


  postProtectedResource: (url, tokenData, done) ->
    url.method = 'POST'
    @fetchProtectedResource url, tokenData, done


  fetchProfile: (tokenData, done) ->
    url = @url 'profile', tokenData
    @fetchProtectedResource url, tokenData, (error, data) =>
      return done(error or new Error 'Failed to get user profile') unless data
      @validateResponse data, (error, data) =>
        return done error if error
        @parseProfile data, done


  fetchFriends: (tokenData, done) ->
    url = @url 'friends', tokenData
    @fetchProtectedResource url, tokenData, (error, data) =>
      return done(error or new Error 'Failed to get friends') unless data
      @validateResponse data, (error, data) =>
        return done error if error
        @parseProfiles data, done


  postMessageTo: (user_id, message, tokenData, done) ->
    url = @url 'postTo', _.extend {}, tokenData, user_id:user_id, message:message
    @postProtectedResource url, tokenData, (error, data) =>
      return done(error or new Error 'Failed to post message') unless data
      @validateResponse data, done


  postMessage: (message, tokenData, done) ->
    url = @url 'post', _.extend {}, tokenData, message:message
    @postProtectedResource url, tokenData, (error, data) =>
      return done(error or new Error 'Failed to post message') unless data
      @validateResponse data, done


  validateResponse: (resp, done) -> done new Error 'validateResponse not implemented'

  parseProfile: (data, done) -> done new Error "parseProfile not implemented"

  parseProfiles: (data, done) -> async.map data, @parseProfile.bind(@), done
