_    = require 'underscore'
Q    = require 'querystring'
URL  = require 'url'
util = require './util'

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


  fetchProtectedResource: (name, tokenData, done) ->
    url = @url name, tokenData
    useJson = if @get('useJson') == false then false else true
    util.perform_request url, (error, data) ->
      return done error if error
      if useJson
        try
          data = JSON.parse data
        catch err
          return done err
      done null, data


  fetchProfile: (tokenData, done) ->
    @fetchProtectedResource 'profile', tokenData, (error, data) =>
      return done(error or 'Failed to get user profile') unless data
      @validateResponse data, (error, data) =>
        return done error if error
        @parseProfile data, done


  fetchFriends: (tokenData, done) ->
    @fetchProtectedResource 'friends', tokenData, (error, data) =>
      return done(error or 'Failed to get friends') unless data
      @validateResponse data, (error, data) =>
        return done error if error
        @parseProfiles data, done


  parseProfile: (data, done) -> done "parseProfile not implemented"


  parseProfiles: (data, done) ->
    profiles = []
    last_error = null
    for prof in data
      @parseProfile prof, (error, profile) ->
        last_error = error if error
        profiles.push profile if profile
    return done last_error unless profiles.length
    done null, profiles


  validateResponse: (resp, done) ->
    return done resp.error if resp.error
    done null, resp
