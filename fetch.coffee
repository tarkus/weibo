qs      = require 'querystring'
redis   = require 'redis'
prompt  = require 'prompt'
request = require 'request'
{Nohm}  = require 'nohm'

User  = require './models/user'
Weibo = require './models/weibo'

config =
  loginURL: 'http://m.weibo.cn/login'
  fetchURL: 'http://m.weibo.cn/home/homeData'
  userId: 1195403385
  email: ''
  passwd: ''

credentialPrompt = (next) ->
  prompt.message = ''
  prompt.delimiter = ''

  prompt.start()
  console.log "You've been signed out. Enter your weibo.com account info to continue".green

  prompt.get
    properties:
      email:
        description: "Email ".yellow
        message: 'Enter your email to continue'
      password:
        hidden: true
        message: ''
        description: "Password ".yellow
  , (err, result) ->
    process.exit() unless result.email? and result.password?
    config.email = result.email
    config.passwd = result.passwd
    next()

login = (next) ->
  params =
    check: 1
    backURL: "http://m.weibo.cn"
    uname: config.email
    pwd: config.passwd
    autoLogin: 1

  j = request.jar()
  
  request.post login.url,
    body: qs.stringify(params)
    jar: j
  , (err, res, body) ->
    console.log j
    console.log res, body
    next()

fetch = (params) ->
  params = params or page: 1
  console.log 'Fetching page #' + params.page
  request config.fetchURL,
    qs:
      u: config.userId
      hideAvanta: 1
      page: params.page
      _: new Date().getTime()
  , (err, res, body) ->
    return console.log err if err?
    try
      json = JSON.parse(body)
    catch e
      return console.log e
    store(json)


halt = (err) ->
  console.log err

store = (data) ->
  console.log data

  userInfo = data.userInfo

  createUser = (data, next) ->
    user = new User
    user.prop
      user_id: data.id
      name: data.name
      raw: data
    user.save (err) ->
      return halt err if err?
      next()

  updateUser = (data, next) ->
    User.load parseInt(ids[0]), (err, props) ->
      @prop
        raw: data
        updated_at: new Date()
      @save (err) ->
        return halt err if err?
        next()

  createWeibo = (data, next) ->
    weibo = new Weibo
    weibo.prop
      user_id:  data.uid
      weibo_id: data.id
      raw: data
    weibo.save (err) ->
      if err is 'notUnique'
        Weibo.find weibo_id: data.id, (err, ids) ->
          return halt err if err? or ids.length is not 1
          Weibo.load parseInt(ids[0]), (err, props) ->
            @prop
              raw: data
              updated_at: new Date()
            @save()
              
            
      return halt err if err?
      next()


  User.find userInfo.id, (err, ids) ->
    if ids.length < 1 or err?
      createUser -> createWeibo
    else
      updateUser -> createWeibo

  stats.maxPage = data.maxPage
  stats.total = data.total_number
  for id, t of data.mblogList
    console.log t.info

###
  request config.fetchURL,
    followRedirect: false
    , (err, res, body) ->
      return console.log err if err?
      if res.headers.statusCode is 302
        promptCredential -> login -> fetch
###
        
redisClient = redis.createClient()

redisClient.on 'connect', ->

  Nohm.setClient redisClient
  Nohm.setPrefix 'weibo'

  fetch()

