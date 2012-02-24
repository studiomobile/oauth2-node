_ = require 'underscore'

module.exports = class Options
  constructor: (@options) ->
    @options or= {}

  get: (key) ->
    @options[key]

  set: (key, value) ->
    return unless key
    if key.constructor == Object
      @options = @effective_options key
    else
      @options[key] = value
    return

  effective_options: (options) ->
    _.defaults _.clone(options), @options
