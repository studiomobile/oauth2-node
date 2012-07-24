Q    = require 'querystring'
URL  = require 'url'
util = require './util'
OAuth2Error = require './error'

module.exports = class Gateway extends require('./options')
  constructor: (@strategy, options) ->
    super options

  middleware: ->
    clientID = @options.clientID
    throw new Error "Please provide 'clientID' option" unless clientID
    clientSecret = @options.clientSecret
    throw new Error "Please provide 'clientSecret' option" unless clientSecret

    strategy = @strategy
    throw new Error "Please provide valid strategy" unless strategy?.url?.constructor == Function

    dialogUrl = strategy.url 'dialog'
    throw new Error "Can't get login dialog url" unless dialogUrl?.hostname
    dialogQuery = dialogUrl.query or= {}
    dialogQuery.scope = strategy.formatScope @options.scope
    dialogQuery.client_id = clientID
    dialogQuery.response_type = 'code'

    tokenUrl = strategy.url 'token'
    throw new Error "Can't get access token url" unless tokenUrl?.hostname
    tokenQuery = tokenUrl.query or= {}
    tokenQuery.grant_type = 'authorization_code'
    tokenQuery.client_id = clientID
    tokenQuery.client_secret = clientSecret

    displayType = @options.display
    successPath = @options.successPath
    errorPath   = @options.errorPath
    sessionKey  = @options.sessionKey

    onError = (res, next, error) ->
      if errorPath
        res.redirect errorPath
      else
        error = new OAuth2Error error if typeof error == 'string'
        next error

    onSuccess = (req, res, next, oauth, profile) ->
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

    fetchProfile = (req, res, next, oauth) ->
      strategy.fetchProfile oauth, (error, profile) ->
        return onError res, next, error unless profile
        onSuccess req, res, next, oauth, profile

    (req, res, next) ->
      url = URL.parse(req.url, true)
      query = url.query
      
      # error response from provider
      if query.error
        return onError res, next, new OAuth2Error query.error_description, code:query.error, reason:query.error_reason

      # authorize with access_token
      if query.access_token
        return fetchProfile req, res, next, query

      hostparts = req.headers.host.split ':' if req.headers.host.indexOf('[') == -1

      redirectUrl = URL.format
        protocol: if req.connection.encrypted then 'https' else 'http'
        hostname: hostparts?[0] or req.headers.host
        port:     hostparts?[1]
        pathname: url.pathname

      # authorization code from provider, exchange it to access_token and fetch profile
      if query.code
        tokenQuery.code = query.code
        tokenQuery.redirect_uri = redirectUrl
        return util.perform_request tokenUrl, (error, data) ->
          oauth = parse_token_data data if data
          return onError(res, next, error or 'Failed to get access token') unless oauth
          return onError(res, next, oauth.error) if oauth.error
          fetchProfile req, res, next, oauth

      # We don't have any expected parameters from provider, just redirect client to provider's authorization dialog page
      dialogQuery.display = displayType or strategy.dialogDisplayType(req)
      dialogQuery.redirect_uri = redirectUrl
      res.redirect URL.format dialogUrl


parse_token_data = (data) ->
  try
    JSON.parse(data)
  catch err
    Q.parse(data)
