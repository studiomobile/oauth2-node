module.exports = class Strategy extends require('../strategy')
  constructor: ->
    super
    @scopeSeparator = ' '
    @regUrl 'dialog', protocol:'https', hostname:'accounts.google.com', pathname:'/o/oauth2/auth'
    @regUrl 'token',  protocol:'https', hostname:'accounts.google.com', pathname:'/o/oauth2/token', method:'POST'
    @regUrl 'profile', (data) ->
      protocol: 'https'
      hostname: 'www.googleapis.com'
      pathname: "/oauth2/v1/userinfo"
      query:
        access_token: data.access_token
      headers:
        Authorization: "Bearer #{data.access_token}"


  parseProfile: (data, done) ->
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
