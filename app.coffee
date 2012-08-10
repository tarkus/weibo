express = require 'express'
routes = require './routes'
http = require 'http'
path = require 'path'
querystring = require 'querystring'

app = express()

app.configure ->
  app.set 'port', process.env.PORT || 4444
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.favicon()
  app.use express.logger('dev')
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser('no country for old man')
  app.use express.session()
  app.use app.router
  app.use express.static(path.join(__dirname, 'public'))
  app.use require('connect-assets')()

app.configure 'development', -> app.use express.errorHandler()

need_authorize = (req, res, next) ->
  unless req.session.oauth_access_token?
    return res.redirect '/login?redirect=' + querystring.escape(req.originalUrl)
  next()
  
app.get '/login', routes.login
app.get '/callback', routes.callback
app.get '/', need_authorize, routes.index

exports.boot = boot = ->
  http.createServer(app).listen app.get('port'), ->
    console.log "Server is listening on port " + app.get('port')

boot() if require.main == module
