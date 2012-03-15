module.exports = class Gateway extends require('../gateway')
  constructor: ->
    super
    @options.scopeSeparator = ','
    @options.dialogUrl = 'http://oauth.vk.com/authorize'
    @options.tokenUrl = 'https://oauth.vk.com/access_token'


Gateway::profile_url = (data) ->
  protocol: 'https'
  hostname: 'api.vk.com'
  pathname: '/method/users.get'
  query:
    uid: data.user_id
    fields: 'uid,first_name,last_name,nickname,screen_name,sex,bdate'
    access_token: data.access_token


Gateway::parse_profile = (data, done) ->
  try
    data = JSON.parse data
    return done data.error if data.error
    data = data.response[0]
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
      displayName: data.nickname or "#{data.first_name} #{data.last_name}"
  catch err
    done err
