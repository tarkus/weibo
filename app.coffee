express = require 'express'
http    = require 'http'
path    = require 'path'
qs      = require 'querystring'
{Nohm}  = require 'nohm'
redis   = require 'redis'
helper  = require './lib/helper'
config  = require './config'

RedisStore = require('connect-redis')(express)
sessionStore = new RedisStore

redisClient = redis.createClient()

app = express()
app.set 'port', process.env.PORT || 5000
app.set 'views', __dirname + '/views'
app.set 'view engine', 'jade'

need_authorize = (req, res, next) ->
  unless req.session.oauth_access_token?
    return res.redirect '/login?redirect=' + qs.escape(req.originalUrl)
  next()

app.configure ->
  app.use express.favicon()
  app.use express.logger('dev')
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser('no country for old man')
  app.use express.session
    secret: "it's bad for you"
    maxAge: 1000 * 86400 * 30 * 12
    store: sessionStore
  app.use app.router
  app.use express.static(path.join(__dirname, 'public'))
  app.use require('connect-assets') src: 'public'

app.configure 'development', -> app.use express.errorHandler()

redisClient.on 'connect', ->
  Nohm.setClient redisClient
  Nohm.setPrefix 'weibo-oauth'

  routes = require('./routes')(app)

  app.get '/login', routes.login
  app.get '/callback', routes.callback
  if config.fetch_mode? and config.fetch_mode is 1
    app.get '/', need_authorize, routes.index
  else
    app.get '/', routes.index

exports.boot = boot = ->
  server = http.createServer(app)

  io = require('socket.io').listen server

  io.configure ->
    io.set 'log level', 1
    if process.env.REDISTOGO_URL?
      io.set 'transports', ['xhr-polling']
      io.set 'polling duration', 10

  io.sockets.on 'connection', (socket) ->

    app.socket = socket
    socket.emit 'connected', true
    
  io.sockets.on 'disconnect', () ->

    delete app.socket

  server.listen app.get('port'), ->
    console.log "Server is listening on port " + app.get('port')

boot() if require.main == module
