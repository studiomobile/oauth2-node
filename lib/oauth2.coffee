connect = require 'connect'
Guard   = require './guard'
util    = require './util'

module.exports = class OAuth2 extends require('./options')
  constructor: ->
    super
    @routes = {}

  guard: (options) ->
    new Guard(@effective_options options).middleware()

  gateway: (name, options) ->
    OAuth2.gateway(name, @effective_options options).middleware()

  route: (path, name, options) ->
    @routes[path] = @gateway name, options

  middleware: ->
    routes = @routes
    connect.router (app) ->
      Object.keys(routes).forEach (path) ->
        app.get path, routes[path]


OAuth2.Guard = Guard
OAuth2.guard = (options) -> new Guard(options)


OAuth2.Storage = require './storage'
OAuth2.available_storages = util.load_modules_from_dir __dirname, 'storage'
OAuth2.storage = (name, options) ->
  Storage = OAuth2.available_storages[name]
  throw new Error("There is no '#{name}' storage for OAuth2") unless Storage
  new Storage options


OAuth2.Gateway = require './gateway'
OAuth2.available_gateways = util.load_modules_from_dir __dirname, 'gateway'
OAuth2.gateway = (name, options) ->
  Gateway = OAuth2.available_gateways[name]
  throw new Error("There is no '#{name}' gateway for OAuth2") unless Gateway
  new Gateway options
  