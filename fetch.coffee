qs      = require 'querystring'
redis   = require 'redis'
prompt  = require 'prompt'
request = require 'request'
{Nohm}  = require 'nohm'

User  = require './models/user'
Weibo = require './models/weibo'

config  = require './config'

askForCredential = (next) ->
  prompt.message = ''
  prompt.delimiter = ''

  prompt.start()
  console.log "Need login, enter your weibo.com account info to continue".green

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
    process.exit() if err? or not (result.email? and result.password?)
    config.email = result.email
    config.passwd = result.passwd
    next?()

login = (next) ->
  request.post config.login_url,
    body: qs.stringify
      check: 1
      backURL: "http://m.weibo.cn"
      uname: config.email
      pwd: config.passwd
      autoLogin: 1
  , (err, res, body) ->
    console.log res, body
    #next?()

fetch = (options, callback) ->
  if typeof arguments[0] is 'function'
    callback = options
    options = null
  options = options or page: 1
  console.log 'Fetching page #' + options.page

  params =
    qs:
      u: config.user_id
      hideAvanta: 1
      page: options.page
      below: '&'
      _: Date.now()
    followRedirect: false

  if config.cookie? and config.cookie.length > 0
    j = request.jar()
    for piece in config.cookie.split ';'
      cookie = request.cookie piece
      j.add cookie
    params.jar = j

  request config.fetch_url, params, (err, res, body) ->
    if err? or res.headers.statusCode is not 200
      return halt 'Fetching Error:', body

    try
      json = JSON.parse(body)
    catch e
      return halt 'Fetching Error:', body + " - " + e

    if json.ok is -100
      return askForCredential -> login -> fetch(options, callback)

    store json, ->
      console.log "Saved #{Object.keys(json.mblogList).length} entries"
      return callback() if options.page is json.maxPage
      console.log "#{json.maxPage - options.page} pages left, take a rest"
      setTimeout ->
        fetch page: options.page + 1, -> callback()
      , 6000


halt = (msg, err) ->
  if arguments.length is 1
    err = msg
    msg = ''
  console.log msg + " " + JSON.stringify(err)
  process.exit(-1)

store = (data, next) ->
  userData = data.userInfo
  weiboData = data.mblogList
  now = Math.round(Date.now() / 1000)

  return halt data if not userData? and not weiboData?

  storeUser = (data, next) ->
    return next?() unless data?
    user = new User
    user.prop
      user_id: data.id
      name: data.name
      raw: data
    user.save (err) ->
      return next?() unless err
      if @errors.user_id.length is not 1
        return halt 'storeUser::create', @errors
      if @errors.user_id[0] is not 'notUnique'
        return halt 'storeUser::create', @errors
      User.find user_id: data.id, (err, ids) ->
        return halt 'storeUser::update', err if err
        User.load parseInt(ids[0]), (err, props) ->
          @prop
            raw: data
            updated_at: now
          @save (err) ->
            return halt "storeUser::update", err if err
            return next?()

  storeWeibo = (data, next) ->
    total = Object.keys(data).length
    count = 0
    for id, entry of data
      weibo = new Weibo
      weibo.prop
        user_id:  entry.uid
        weibo_id: id
        raw: entry
      weibo.save (err) ->
        unless err
          count++
          return next?() if total is count
        if @errors.weibo_id.length is not 1
          return halt 'storeWeibo::create', @errors
        if @errors.weibo_id[0] is not 'notUnique'
          return halt 'storeWeibo::create', @errors
        Weibo.find weibo_id: id, (err, ids) ->
          return halt 'storeWeibo::update', err if err?
          Weibo.load parseInt(ids[0]), (err, props) ->
            @prop
              raw: entry
              updated_at: now
            @save (err) ->
              return halt 'storeWeibo::update', err if err?
              count++
              return next?() if total is count
              
  storeUser userData, -> storeWeibo weiboData, -> next()

redisClient = redis.createClient()

redisClient.on 'connect', ->

  Nohm.setClient redisClient
  Nohm.setPrefix 'weibo'

  #fetch ->
  fetch page: 12, ->
    console.log 'Done'
    process.exit()
