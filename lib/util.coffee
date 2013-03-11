path   = require 'path'
fs     = require 'fs'
http   = require 'http'
https  = require 'https'
Q      = require 'querystring'
_      = require 'underscore'


module.exports.normalize_scope = (scope) ->
  scope or= []
  scope = scope.split /[\s,]/ if _.isFunction scope.split
  _.compact _.flatten [].concat [scope]...


module.exports.normalize_expire = (expire) ->
  return expire unless expire
  expire = parseInt(expire) if _.isString expire
  expire = expire.getTime if _.isFunction expire.getTime
  return expire


module.exports.load_modules_from_dir = ->
  dir = path.join(arguments...)
  modules = {}
  fs.readdirSync(dir).forEach (filename) ->
    name = path.basename(filename, path.extname(filename))
    try
      modules[name] = require path.join(dir, name)
    catch err
      console.log "Failed to load module", name, err
  modules


module.exports.perform_request = (url, done) ->
  post_data = Q.stringify(url.query) if url.method?.match /^POST$/i and url.query
  if post_data
    delete url.query
    url.headers or= {}
    url.headers['Content-Type'] = 'application/x-www-form-urlencoded'
    url.headers['Content-Length'] = post_data.length

  protocol = http
  if url.protocol?.match /^https/i
    protocol = https
    url.protocol = null

  url.path = url.pathname
  url.path = url.path + '?' + Q.stringify(url.query) if url.query

  req = protocol.request url, (res) ->
    data = ''
    res.on 'data', (chunk) -> data += chunk
    res.on 'end', -> done null, data, res
  req.on 'error', done
  req.write post_data if post_data
  req.end()
