URL = require 'url'
Err = require '../error'
request = require 'request'


module.exports = class Strategy extends require('../strategy_1.0a')
  constructor: ->
    super
    @regUrl 'request', 'https://twitter.com/oauth/request_token'
    @regUrl 'dialog', 'https://twitter.com/oauth/authenticate'
    @regUrl 'token', 'https://twitter.com/oauth/access_token'
    @regUrl 'profile', -> @apiUrl 'account/verify_credentials'
    @regUrl 'friends', -> @apiUrl 'friends/list'
    @regUrl 'post', (data) -> @apiUrl 'direct_messages/new', user_id:data.user_id, text:data.message

  apiUrl: (method, query) -> protocol:'https', hostname:'api.twitter.com', pathname:"/1.1/#{method}.json", query:(query or {})


  parseProfile: (data, done) ->
    done null,
      provider: 'twitter'
      id: data.id
      username: data.screen_name
      displayName: data.name
      profileUrl: "https://twitter.com/#{data.screen_name}"


  fetchFriends: (tokenData, done) ->
    oauth = @prepareOAuth tokenData
    friendsUrl = @url 'friends'
    friendsUrl.query or= {}
    friendsData = []
    fetchFriendsPage = (cursor) =>
      friendsUrl.query.cursor = cursor
      request.get url:URL.format(friendsUrl), oauth:oauth, json:true, (error, response, data) =>
        return done error if error
        @validateResponse data, (error, data) =>
          return done error if error
          friendsData.push data.users...
          return fetchFriendsPage(data.next_cursor_str) if data.next_cursor_str != '0'
          @parseProfiles friendsData, done
    fetchFriendsPage -1


  validateResponse: (data, done) ->
    error = data.error if data.error
    error = data.errors[0] if data.errors?[0]
    switch error?.code
      when 89, 215
        error = Err.Unauthorized
    done error, data
