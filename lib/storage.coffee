util = require './util'

module.exports = class Storage extends require('./options')
  constructor: ->
    super

  save_token_data: (data, done) ->
    done new Error "Not implemented persist_token_data"

  get_token_data: (token, done) ->
    done new Error "Not implemented fetch_token_data"

  delete_token_data: (token, done) ->
    done new Error "Not implemented delete_token_data"
