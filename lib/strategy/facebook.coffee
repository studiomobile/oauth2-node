Err = require '../error'

PostFields = 'picture link name caption description source icon type'.split ' '

module.exports = class Strategy extends require('../strategy')
  constructor: ->
    super
    @regUrl 'dialog', protocol:'http', hostname:'facebook.com', pathname:'/dialog/oauth'
    @regUrl 'token',  @_graphUrl 'oauth/access_token'
    @regUrl 'profile', (data) -> @_graphUrl 'me', access_token:data.access_token
    @regUrl 'friends', (data) -> @_graphUrl 'me/friends', access_token:data.access_token
    @regUrl 'post',    (data) -> @_graphUrl "me/feed", @_postMessageQuery data
    @regUrl 'postTo',  (data) -> @_graphUrl "#{data.user_id}/feed", @_postMessageQuery data

  _graphUrl: (method, query) -> protocol:'https', hostname:'graph.facebook.com', pathname:"/#{method}", query:(query or {})

  
  _postMessageQuery: (data) ->
    msg = data.message
    query = message:msg.text, access_token:data.access_token
    for field in PostFields
      query[field] = msg[field] if msg[field]
    query


  parseProfile: (data, done) ->
    dateParts = data.birthday?.split '/' if /^\d+\/\d+\/\d+$/.test data.birthday
    done null,
      provider: 'facebook'
      id: data.id
      username: data.username
      displayName: data.name
      name:
        familyName: data.last_name
        givenName: data.first_name
        middleName: data.middle_name
      bdate: new Date dateParts[2], dateParts[0]-1, dateParts[1], 12 if dateParts
      gender: data.gender
      profileUrl: data.link or "http://facebook.com/#{data.id}"
      emails: [value: data.email] if data.email


  validateResponse: (resp, done) ->
    error = resp.error if resp.error
    code = error?.code
    switch code
      when 10, 102, 190, 2500
        error = Err.Unauthorized error.message, code:code
    if code >= 200 and code <= 299
      error = Err.Unauthorized error.message, code:code 
    done error, (resp.data or resp)
