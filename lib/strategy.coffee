_    = require 'underscore'
UA   = require 'ua-parser'
URL  = require 'url'
util = require './util'

module.exports = class Strategy extends require('./options')
  constructor: ->
    super
    @scopeSeparator = ','
    @_urls = {}

  url: (type, data) ->
    url = @_urls[type]
    @parseUrl url, data if url

  parseUrl: (url, data) ->
    return URL.parse url.replace(/\{\{(.+?)\}\}/g, ($0, $1) -> data[$1] || ''), true if _.isString url
    return url.call @, data if _.isFunction url
    url

  regUrl: (type, url) ->
    @_urls[type] = url

  formatScope: (scope) ->
    util.normalize_scope(scope).join @scopeSeparator

  fetchProfile: (oauth, done) ->
    self = @
    util.perform_request @url('profile', oauth), (error, data) ->
      return done(error or 'Failed to get user profile') unless data
      self.json data, done, self.parseProfile

  fetchFriends: (oauth, done) ->
    self = @
    util.perform_request @url('friends', oauth), (error, data) ->
      return done(error or 'Failed to get friends') unless data
      self.json data, done, self.parseProfiles

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

  dialogDisplayType: (req) ->
    ua = UA.parse req.headers['user-agent']
    switch ua.family
      when 'iPhone' then 'touch'
      else 'page'

  json: (json, done, next) ->
    self = @
    try
      resp = JSON.parse json
      @validateResponse resp, (error, data) ->
        return done error if error
        try
          next.call self, data, done
        catch error
          done error
    catch error
      done error

  validateResponse: (resp, done) ->
    return done resp.error if resp.error
    done null, resp
