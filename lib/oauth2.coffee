Gateway = require './gateway'
Guard   = require './guard'
util    = require './util'

module.exports = class OAuth2 extends require('./options')
  constructor: ->
    super
    @._accessor 'storage'

  guard: (options) ->
    new Guard(@_effective options).middleware()

  gateway: (type, options) ->
    strategy = OAuth2.strategy type, options
    new Gateway(strategy).middleware()


OAuth2.Gateway = Gateway
OAuth2.Guard   = Guard
OAuth2.Error   = require './error'

OAuth2.Storage = require './storage'
OAuth2.available_storages = util.load_modules_from_dir __dirname, 'storage'
OAuth2.storage = (type, options) ->
  Storage = OAuth2.available_storages[type]
  throw new Error("There is no '#{type}' storage for OAuth2") unless Storage
  new Storage options

OAuth2.Strategy = require './strategy'
OAuth2.available_strategies = util.load_modules_from_dir __dirname, 'strategy'
OAuth2.strategy = (type, options) ->
  Strategy = OAuth2.available_strategies[type]
  throw new Error("There is no '#{type}' strategy for OAuth2") unless Strategy
  new Strategy options
  