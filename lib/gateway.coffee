URL  = require 'url'
util = require './util'

module.exports = class Gateway extends require('./options')
  constructor: ->
    super

  middleware: ->
    clientID = @options.clientID
    throw new Error "Please provide 'clientID' option" unless clientID
    clientSecret = @options.clientSecret
    throw new Error "Please provide 'clientSecret' option" unless clientSecret

    dialogUrl = util.parse_url(@options.dialogUrl or @dialog_url)
    throw new Error "Please provide 'dialogUrl' option or implement 'dialog_url' method" unless dialogUrl?.hostname
    dialogQuery = dialogUrl.query or= {}
    dialogQuery.scope = util.normalize_scope(@options.scope).join(@options.scopeSeparator || ' ')
    dialogQuery.client_id = clientID
    dialogQuery.response_type = 'code'

    tokenUrl = util.parse_url(@options.tokenUrl or @token_url)
    throw new Error "Please provide 'tokenUrl' option or implement 'token_url' method" unless tokenUrl?.hostname
    tokenQuery = tokenUrl.query or= {}
    tokenQuery.grant_type = 'authorization_code'
    tokenQuery.client_id = clientID
    tokenQuery.client_secret = clientSecret

    profile_url = @options.profileUrl or @profile_url
    throw new Error "Please provide profileUrl" unless profile_url

    parse_profile = @options.parseProfile or @parse_profile
    throw new Error "Please provide function 'parseProfile' or implement 'parse_profile' method" unless parse_profile
    throw new Error "Provided parseProfile is not a function" unless typeof parse_profile == 'function'
    
    displayType = @options.display
    successPath = @options.successPath or 'home'
    errorPath   = @options.errorPath
    sessionKey  = @options.sessionKey || 'oauth'
    
    (req, res, next) ->
    
      onError = (error) ->
        if errorPath
          res.redirect errorPath
        else
          # TODO: wrap to OAuth2.Error
          next(error)

      onSuccess = (auth) ->
        if session = req.session
          session[sessionKey] = auth
          session.save()
        res.redirect successPath
        
      url = URL.parse(req.url, true)
      query = url.query
      
      if query.error
        # We've got error from provider: user did cancel authorization, etc.
        # TODO: create OAuth2.Error
        return onError("#{query.error}:#{query.error_reason}: #{query.error_description}")

      fullUrl = URL.format
        protocol: if req.connection.encrypted then 'https' else 'http'
        hostname: req.headers.host
        pathname: url.pathname

      if query.code
        tokenQuery.code = query.code
        tokenQuery.redirect_uri = fullUrl
        # We've got authorization code from provider, let's get access_token
        return util.perform_request tokenUrl, (error, data) =>
          oauth = util.parse_response_data data if data
          return onError(error or 'Failed to get access token') if error or !oauth
          return onError(oauth.error) if oauth.error
          # We've got access_token, let's get profile
          util.perform_request util.parse_url(profile_url, oauth), (error, data) ->
            return onError(error or 'Failed to get user profile') unless data
            # We've got profile response, let's get profile
            parse_profile data, (error, profile) ->
              return onError(error or 'Bad profile data received') unless profile
              oauth.profile = profile
              onSuccess(oauth)

      # We don't have any expected parameters from provider, just redirect client to provider's authorization dialog page
      dialogQuery.display = displayType or util.dialog_display_type(req)
      dialogQuery.redirect_uri = fullUrl
      res.redirect URL.format dialogUrl
