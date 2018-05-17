Err = require '../error'

module.exports = class Strategy extends require('../strategy')
  constructor: ->
    super
    profileFields = 'uid,first_name,last_name,nickname,screen_name,sex,bdate,photo_max_orig,photo_400_orig,photo_200'
    @regUrl 'dialog', protocol:'http', hostname:'oauth.vk.com', pathname:'/authorize'
    @regUrl 'token', protocol:'https', hostname:'oauth.vk.com', pathname:'/access_token'
    @regUrl 'profile', (data) -> @_apiUrl 'users.get',   uid:data.user_id, fields:profileFields, access_token:data.access_token
    @regUrl 'friends', (data) -> @_apiUrl 'friends.get', uid:data.user_id, fields:profileFields, access_token:data.access_token
    @regUrl 'post',    (data) -> @_apiUrl 'wall.post', @_postMessageQuery data
    @regUrl 'postTo',  (data) -> @_apiUrl 'wall.post', @_postMessageQuery data, data.user_id


  _apiUrl: (method, query) ->
    protocol:'https',
    hostname:'api.vk.com',
    pathname:"/method/#{method}",
    query:(Object.assign {v:'3.5'}, query or {})

  _postMessageQuery: (data, owner_id) ->
    msg = data.message
    query = message:msg.text, access_token:data.access_token
    query.owner_id = owner_id if owner_id
    query.attachments = msg.attachments if msg.attachments
    query


  parseProfile: (resp, done) ->
    data = if resp.constructor == Array then resp[0] else resp
    dateParts = data.bdate?.split '.' if /^\d+\.\d+\.\d+$/.test data.bdate
    done null,
      rawData:data
      provider: 'vk'
      id: data.uid
      gender: switch data.sex
        when 1 then "female"
        when 2 then "male"
        else "undisclosed"
      name:
        familyName: data.last_name
        givenName: data.first_name
      bdate: new Date dateParts[2], dateParts[1]-1, dateParts[0], 12 if dateParts
      displayName: data.nickname or "#{data.first_name} #{data.last_name}"
      profileUrl: "http://vk.com/id#{data.uid}"
      pictureUrl: data.photo_max_orig or data.photo_400_orig or data.photo_200


  validateResponse: (resp, done) ->
    error = resp.error if resp.error
    switch error?.error_code
      when 5, 7, 20, 113, 214
        error = Err.Unauthorized error.error_msg, code:error.error_code
    done error, resp.response
