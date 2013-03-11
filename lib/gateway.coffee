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

    fetchProfile = (req, oauth, done) ->
      strategy.fetchProfile oauth, (error, profile) ->
        return done error or 'Failed to fetch profile' unless profile
        oauth.profile = profile
        req.oauth = oauth
        done null

    (req, res, next) =>
      done = (error, oauth, redirect) ->
        return onError next, error if error
        return res.redirect URL.format redirect if redirect
        fetchProfile req, oauth, (error) ->
          return onError next, error if error
          next()

      url = URL.parse req.url, true
      return done null, url.query if url.query.access_token # authorize with given access_token
      redirect = URL.format
        protocol: if req.connection.encrypted then 'https' else 'http'
        host:     req.headers.host
        pathname: url.pathname
      handler.call @, strategy, url.query, redirect, req, done


  _oauth2: (strategy, query, redirect, req, done) ->
      # error response from provider
      if query.error
        return done new OAuth2Error query.error_description, code:query.error, reason:query.error_reason
      # authorization code from provider, exchange it to access_token
      if query.code
        return strategy.fetchAccessToken query.code, redirect:redirect, (error, tokenData) ->
          return done error or 'Failed to get access token' unless tokenData
          done null, tokenData
      # We don't have any expected parameters from provider, just redirect client to provider's authorization dialog page
      strategy.prepareDialogUrl redirect:redirect, display:dialogDisplayType(req), (error, dialogUrl) ->
        return done error or 'Failed to get dialog url' unless dialogUrl
        done null, null, dialogUrl


  _oauth1: (strategy, query, redirect, req, done) ->
    return done 'Canceled by user' if query.denied
    # got verification code from provider and have request dialog data, exchange it to access_token
    if query.oauth_verifier and dialogData = req.session.oauthRequestDialogData
      delete req.session.oauthRequestDialogData
      return strategy.fetchAccessToken query.oauth_verifier, dialogData, (error, tokenData) =>
        return done error or 'Failed to get access token' unless tokenData
        done null, tokenData
    # We don't have verifier from provider and prepared dialog in session, lets display dialog
    strategy.prepareDialogUrl redirect:redirect, (error, dialogUrl, dialogData) =>
      return done error or 'Failed to get dialog url' unless dialogData
      req.session.oauthRequestDialogData = dialogData
      done null, null, dialogUrl


dialogDisplayType = (req) ->
  ua = UA.parse req.headers['user-agent']
  switch ua.family
    when 'iPhone' then 'touch'
    else 'page'
