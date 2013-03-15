Err = require '../error'

module.exports = class Strategy extends require('../strategy')
  constructor: ->
    super
    profileFields = 'uid,first_name,last_name,nickname,screen_name,sex,bdate'
    @regUrl 'dialog', protocol:'http', hostname:'oauth.vk.com', pathname:'/authorize'
    @regUrl 'token', protocol:'https', hostname:'oauth.vk.com', pathname:'/access_token'
    @regUrl 'profile', (data) -> @apiUrl 'users.get',   uid:data.user_id, fields:profileFields, access_token:data.access_token
    @regUrl 'friends', (data) -> @apiUrl 'friends.get', uid:data.user_id, fields:profileFields, access_token:data.access_token
    @regUrl 'post', (data) -> @apiUrl 'wall.post', owner_id:data.user_id, message:data.message, access_token:data.access_token


  apiUrl: (method, query) -> protocol:'https', hostname:'api.vk.com', pathname:"/method/#{method}", query:(query or {})


  parseProfile: (resp, done) ->
    data = if resp.constructor == Array then resp[0] else resp
    dateParts = data.bdate?.split '.' if /^\d+\.\d+\.\d+$/.test data.bdate
    done null,
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


  validateResponse: (resp, done) ->
    error = resp.error if resp.error
    switch error?.error_code
      when 5, 7, 20, 113
        error = Err.Unauthorized
    done error, resp.response
