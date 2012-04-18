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
      self.parseProfile data, (error, profile) ->
        return done(error or 'Bad profile data received') unless profile
        done null, profile

  fetchFriends: (oauth, done) ->
    self = @
    util.perform_request @url('friends', oauth), (error, data) ->
      return done(error or 'Failed to get friends') unless data
      profiles = []
      last_error = null
      for prof in data
        self.parseProfile prof, (error, profile) ->
          last_error = error if error
          profiles.push profile if profile
      return done last_error unless profiles.length
      done null, profiles

  parseProfile: (data, done) -> done "parseProfile not implemented"

  dialogDisplayType: (req) ->
    ua = UA.parse req.headers['user-agent']
    switch ua.family
      when 'iPhone' then 'touch'
      else 'page'
