path   = require 'path'
fs     = require 'fs'
crypto = require 'crypto'
http   = require 'http'
https  = require 'https'
Q      = require 'querystring'
URL    = require 'url'
_      = require 'underscore'
UA     = require 'ua-parser'


module.exports.normalize_scope = (scope) ->
  scope or= []
  scope = scope.split /[\s,]/ if _.isFunction scope.split
  _.compact _.flatten [].concat [scope]...


module.exports.normalize_expire = (expire) ->
  return expire unless expire
  expire = parseInt(expire) if _.isString expire
  expire = expire.getTime if _.isFunction expire.getTime
  return expire


module.exports.gen_token = ->
  crypto.createHash('sha512')
        .update(crypto.randomBytes(128))
        .digest('base64')


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


module.exports.find_oauth_token = (req) ->
  auth = req.header('Authorization')?.split(' ')
  token = auth[1] if auth?[0] == 'OAuth'
  unless token
    url = URL.parse req.url, true if req.url?
    token = url.query?.oauth_token
  token


module.exports.dialog_display_type = (req) ->
  ua = UA.parse req.headers['user-agent']
  switch ua.family
    when 'iPhone' then 'touch'
    else 'page'


module.exports.parse_url = (url, data) ->
  switch typeof url
    when 'string'
      URL.parse url.replace(/\{\{(.+?)\}\}/g, ($0, $1) -> data[$1] || '')
    when 'function'
      url(data)
    else
      url


module.exports.parse_response_data = (data) ->
  try
    JSON.parse(data)
  catch err
    Q.parse(data)


module.exports.perform_request = (url, done) ->
  handle_response = (res) ->
    data = ''
    res.on 'data', (chunk) ->
      data += chunk
    res.addListener 'end', ->
      done null, data

  post_data = Q.stringify(url.query) if url.method == 'POST' and url.query
  if post_data
    url.query = undefined
    url.headers or= {}
    url.headers['Content-Type'] = 'application/x-www-form-urlencoded'
    url.headers['Content-Length'] = post_data.length

  protocol = http
  if url.protocol == 'https:' or url.protocol == 'https'
    protocol = https
    url.protocol = null

  url.path = url.pathname
  url.path = url.path + '?' + Q.stringify(url.query) if url.query

  req = protocol.request url, handle_response
  req.on 'error', (err) -> done err
  req.write(post_data) if post_data
  req.end()
