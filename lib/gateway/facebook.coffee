module.exports = class Gateway extends require('../gateway')
  constructor: ->
    super
    @options.scopeSeparator = ','
    @options.dialogUrl = 'http://facebook.com/dialog/oauth'
    @options.tokenUrl = 'https://graph.facebook.com/oauth/access_token'
    @options.profileUrl = 'https://graph.facebook.com/me?access_token={{access_token}}'


Gateway::parse_profile = (data, done) ->
  try
    data = JSON.parse data
    done null,
      provider: 'facebook'
      id: data.id
      username: data.username
      displayName: data.name
      name:
        familyName: data.last_name
        givenName: data.first_name
        middleName: data.middle_name
      gender: data.gender
      profileUrl: data.link
      emails: [value: data.email] if data.email
  catch err
    done err
