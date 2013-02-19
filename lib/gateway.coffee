Q    = require 'querystring'
URL  = require 'url'
util = require './util'
OAuth2Error = require './error'


module.exports = class Gateway extends require('./options')
  constructor: (@strategy, options) ->
    super options

  middleware: ->
    config  = @getConfig()
    handler = if @strategy?.version == '1.0a' then @_oauth1 else @_oauth2
    (req, res, next) ->
      url = URL.parse req.url, true
      handler config, req, url, res, next


  _oauth2: (config, req, url, res, next) ->
      query = url.query
      # error response from provider
      if query.error
        return config.onError res, next, new OAuth2Error query.error_description, code:query.error, reason:query.error_reason
      # authorize with access_token
      if query.access_token
        return config.fetchProfile req, res, next, query
      redirectUrl = URL.format
        protocol: if req.connection.encrypted then 'https' else 'http'
        host:     req.headers.host
        pathname: url.pathname
      # authorization code from provider, exchange it to access_token and fetch profile
      if query.code
        return util.perform_request config.prepareTokenUrl(query.code, redirectUrl), (error, data) ->
          oauth = parse_token_data data if data
          return config.onError(res, next, error or 'Failed to get access token') unless oauth
          return config.onError(res, next, oauth.error) if oauth.error
          config.fetchProfile req, res, next, oauth
      # We don't have any expected parameters from provider, just redirect client to provider's authorization dialog page
      res.redirect URL.format config.prepareDialogUrl(req, redirectUrl)


  _oauth1: (config, req, url, res, next) ->
    query = url.query
    client = config.client
    return config.onError res, next, 'Canceled by user' if query.denied
    # verification code from provider, exchange it to access_token and fetch profile
    if query.oauth_verifier
      requestToken = req.session.oauthRequestToken
      requestTokenSecret = req.session.oauthRequestTokenSecret
      return client.getOAuthAccessToken requestToken, requestTokenSecret, query.oauth_verifier, (error, accessToken, accessTokenSecret, results) ->
        return config.onError(res, next, error or 'Failed to get access token') unless accessToken
        config.fetchProfile req, res, next, access_token:accessToken, access_token_secret:accessTokenSecret
    # We don't have verifier from provider, get oauth request token
    client._authorize_callback = URL.format
      protocol: if req.connection.encrypted then 'https' else 'http'
      host:     req.headers.host
      pathname: url.pathname
    return client.getOAuthRequestToken (error, requestToken, requestTokenSecret, results) ->
      return config.onError(res, next, error or 'Failed to get request token') unless requestToken
      req.session.oauthRequestToken = requestToken
      req.session.oauthRequestTokenSecret = requestTokenSecret
      res.redirect URL.format config.prepareDialogUrl(requestToken)


  getConfig: ->
    config = {}
    strategy = config.strategy = @strategy
    throw new Error "Please provide valid strategy" unless strategy?.url?.constructor == Function
    clientSecret = @options.clientSecret
    throw new Error "Please provide 'clientSecret' option" unless clientSecret
    dialogUrl = strategy.url 'dialog'
    throw new Error "Can't get login dialog url" unless dialogUrl?.hostname
    tokenUrl = strategy.url 'token'
    throw new Error "Can't get access token url" unless tokenUrl?.hostname

    successPath = @options.successPath
    errorPath   = @options.errorPath
    sessionKey  = @options.sessionKey

    config.onError = (res, next, error) ->
      if errorPath
        res.redirect errorPath
      else
        error = new OAuth2Error error if typeof error == 'string'
        next error

    config.onSuccess = (req, res, next, oauth, profile) ->
      oauth.profile = profile
      if sessionKey && session = req.session
        session[sessionKey] = oauth
        session.save() if successPath
      else
        req.oauth = oauth
      if successPath
        res.redirect successPath
      else
        next()

    config.fetchProfile = (req, res, next, oauth) ->
      strategy.fetchProfile oauth, (error, profile) ->
        return config.onError res, next, error unless profile
        config.onSuccess req, res, next, oauth, profile

    if strategy.version == '1.0a'
      clientKey = @options.clientKey
      throw new Error "Please provide 'clientKey' option" unless clientKey
      requestUrl = strategy.url 'request'
      throw new Error "Can't get token request url" unless requestUrl?.hostname

      config.client = strategy.getOAuthClient URL.format(requestUrl), URL.format(tokenUrl), clientKey, clientSecret

      config.prepareDialogUrl = (token) ->
        dialogUrl.query = oauth_token:token
        return dialogUrl

    else
      clientID = @options.clientID
      throw new Error "Please provide 'clientID' option" unless clientID
      displayType = @options.display
      scope = strategy.formatScope @options.scope

      config.prepareDialogUrl = (req, redirectUrl) ->
        dialogUrl.query =
          scope: scope
          client_id: clientID
          response_type: 'code'
          display: displayType or strategy.dialogDisplayType(req)
          redirect_uri: redirectUrl
        return dialogUrl

      config.prepareTokenUrl = (accessCode, redirectUrl) ->
        tokenUrl.query =
          grant_type: 'authorization_code'
          client_id: clientID
          client_secret: clientSecret
          code: accessCode
          redirect_uri: redirectUrl
        return tokenUrl

    return config


parse_token_data = (data) ->
  try
    JSON.parse(data)
  catch err
    Q.parse(data)
