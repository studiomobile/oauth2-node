module.exports = class Gateway extends require('../gateway')
  constructor: ->
    super

    @options.dialogUrl =
      protocol: 'https'
      hostname: 'accounts.google.com'
      pathname: '/o/oauth2/auth'

    @options.tokenUrl =
      protocol: 'https'
      hostname: 'accounts.google.com'
      pathname: '/o/oauth2/token'
      method: 'POST'


Gateway::profile_url = (data) ->
  protocol: 'https'
  hostname: 'www.googleapis.com'
  pathname: "/oauth2/v1/userinfo"
  query:
    access_token: data.access_token
  headers:
    Authorization: "Bearer #{data.access_token}"


Gateway::parse_profile = (data, done) ->
  try
    data = JSON.parse data
    done null,
      provider: 'google'
      id: data.id
      displayName: data.name
      name:
        familyName: data.family_name
        givenName: data.given_name
        middleName: data.middle_name
      gender: data.gender
      profileUrl: data.link
      emails: [value: data.email] if data.email
  catch err
    done err
