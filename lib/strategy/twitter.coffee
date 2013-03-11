URL   = require 'url'
oauth = require 'oauth'
request = require 'request'

module.exports = class Strategy extends require('../strategy_1.0a')
  constructor: ->
    super
    @version = '1.0a'
    @regUrl 'request', 'https://twitter.com/oauth/request_token'
    @regUrl 'dialog', 'https://twitter.com/oauth/authenticate'
    @regUrl 'token', 'https://twitter.com/oauth/access_token'
    @regUrl 'profile', 'https://api.twitter.com/1.1/account/verify_credentials.json'
    @regUrl 'friends', 'https://api.twitter.com/1.1/friends/list.json'


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
          friendsData.concat data.users
          return fetchFriendsPage(data.next_cursor_str) if data.next_cursor_str != '0'
          @parseProfiles friendsData, done
    fetchFriendsPage -1
