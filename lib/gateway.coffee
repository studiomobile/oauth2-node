UA  = require 'ua-parser'
URL = require 'url'
OAuth2Error = require './error'


module.exports = class Gateway
  constructor: (@strategy) ->


  middleware: ->
    strategy = @strategy
    handler  = if strategy.version == '1.0a' then @_oauth1 else @_oauth2

    onError = (next, error) ->
      error = new OAuth2Error error if typeof error == 'string'
      next error

    fetchProfile = (req, oauth, next) ->
      strategy.fetchProfile oauth, (error, profile) ->
        return onError next, error or 'Failed to fetch profile' unless profile
        req.oauth = oauth
        req.oauth_profile = profile
        next null

    (req, res, next) =>
      done = (error, oauth, redirect) ->
        return onError next, error if error
        return res.redirect URL.format redirect if redirect
        fetchProfile req, oauth, next

      url = URL.parse req.url, true
      redirect = URL.format
        protocol: if req.connection.encrypted then 'https' else 'http'
        host:     req.headers.host
        pathname: url.pathname
      handler strategy, url.query, redirect, req, done


  _oauth2: (strategy, query, redirect, req, done) ->
      # error response from provider
      return done new OAuth2Error query.error_description, code:query.error, reason:query.error_reason if query.error
      # authorization code from provider, exchange it to access_token
      if query.code
        return strategy.fetchAccessToken query.code, redirect:redirect, (error, tokenData) ->
          return done error or 'Failed to get access token' unless tokenData
          done null, tokenData
      # authorize with given access_token
      return done null, query if query.access_token
      # We don't have any expected parameters from provider, just redirect client to provider's authorization dialog page
      strategy.prepareDialogUrl redirect:redirect, display:dialogDisplayType(req), (error, dialogUrl) ->
        return done error or 'Failed to get dialog url' unless dialogUrl
        done null, null, dialogUrl


  _oauth1: (strategy, query, redirect, req, done) ->
    # error response from provider
    return done 'Canceled by user' if query.denied
    # got verification code from provider and have request dialog data, exchange it to access_token
    if query.oauth_verifier and tokenData = req.session?.oauthRequestTokenData
      delete req.session.oauthRequestTokenData
      return strategy.fetchAccessToken query.oauth_verifier, tokenData, (error, tokenData) =>
        return done error or 'Failed to get access token' unless tokenData
        done null, tokenData
    # authorize with given access_token
    return done null, query if query.oauth_token
    # We don't have verifier from provider and prepared dialog in session, lets display dialog
    strategy.prepareDialogUrl redirect:redirect, (error, dialogUrl, tokenData) =>
      return done error or 'Failed to get dialog url' unless tokenData
      return done 'There is no session in request' unless req.session
      req.session.oauthRequestTokenData = tokenData
      done null, null, dialogUrl


dialogDisplayType = (req) ->
  ua = UA.parse req.headers['user-agent']
  switch ua.family
    when 'iPhone' then 'touch'
    else 'page'
