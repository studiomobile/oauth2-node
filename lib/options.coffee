_ = require 'underscore'

module.exports = class Options
  constructor: (@options) ->
    @options or= {}

  get: (key) ->
    @options[key]

  set: (key, value) ->
    return unless key
    if key.constructor == Object
      @options = @_effective key
    else
      @options[key] = value
    return

  _effective: (options) ->
    _.defaults _.clone(options or {}), @options

  _accessor: (opt) ->
    @.__defineGetter__ opt, => @options[opt]
    @.__defineSetter__ opt, (val) => @options[opt] = val
