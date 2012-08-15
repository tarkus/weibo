{OAuth} = require 'oauth'
config  = require '../config'
qs      = require 'querystring'

Weibo   = require '../models/weibo'
User    = require '../models/user'

halt = ->
  console.log arguments
  
now = exports.now = ->
  Math.round(Date.now() / 1000)


createClient = (req) ->
  return new OAuth req.session.oa._requestUrl,
    req.session.oa._accessUrl,
    req.session.oa._consumerKey,
    req.session.oa._consumerSecret,
    req.session.oa._version,
    req.session.oa._authorize_callback,
    req.session.oa._signatureMethod

fetchUser = (next) ->
  oa = createClient(req)
  params = uid: config.userId

  oa.get config.api_baseurl + 'users/show.json?' + qs.stringify(params),
    req.session.oauth_access_token, req.session.oauth_access_token_secret,
    (err, data, result) ->
      return console.log err if err
      try
        json = JSON.parse(data)
      catch e
        return console.log e
        next(json)

storeUser = exports.storeUser = (data, next) ->
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
          updated_at: now()
        @save (err) =>
          return halt "storeUser::update", err if err
          return next?(@)

getUser = ->
  User.find user_id: config.userId, (err, ids) ->
    if not ids or ids.length is not 1
      return fetchUser -> storeUser userData, -> next userData
    fetchUser -> storeUser userData
    User.load parseInt(ids[0]), (err, props) -> next @prop('raw')

fetchWeibo = (params, next) ->
  defaults =
    uid: config.userId
    trim_user: 1
    count: 100
    page: 1
  params = params or defaults
  params = defaults extends params

  oa = createClient(req)
  oa.get config.api_baseurl + 'statuses/user_timeline.json?' + qs.stringify(params),
    req.session.oauth_access_token, req.session.oauth_access_token_secret,
    (err, data, result) ->
      return console.log err if err
      try
        json = JSON.parse(data)
      catch e
        return console.log e
        next(json)

storeWeibo = exports.storeWeibo = (data, next) ->
  counter = 0
  weiboData = []
  for entry in data
    weibo = new Weibo
    weibo.prop
      user_id: entry.user_id
      weibo_id: entry.id
      raw: entry
    weibo.save (err) =>
      unless err
        counter++
        weiboData.push @prop('raw')
        return next?(userData, weiboData) if counter is data.length
      if @errors.weibo_id.length is not 1
        return halt 'storeWeibo::create', @errors
      if @errors.weibo_id[0] is not 'notUnique'
        return halt 'storeWeibo::create', @errors
      Weibo.find weibo_id: entry.id, (err, ids) ->
        return halt 'storeWeibo::update', err if err?
        Weibo.load parseInt(ids[0]), (err, props) ->
          @prop
            raw: entry
            updated_at: now()
          @save (err) =>
            return halt 'storeWeibo::update', err if err?
            counter++
            weiboData.push @prop('raw')
            return next?(userData, weiboData) if counter is data.length

getWeibo = (userData, next) ->
  Weibo.sort
    field: weibo_id
    direction: 'DESC'
    amount: 50
  , (err, ids) ->
    if ids.length < 1
      return fetchWeibo -> storeWeibo json, -> next(userData, weiboData)
    fetchWeibo -> storeWeibo weiboData
    weiboData = []
    counter = 0
    for id in ids
      Weibo.load parseInt(id), (err, props) ->
        weiboData.push @prop.raw
        if counter is ids.length
          next(userData, weiboData)

module.exports = (app) ->
  
  index: (req, res, next) ->
                
    getUser (userData) -> getWeibo (userData, weiboData) ->
      return next(data) unless userData? and weiboData?
      res.render 'index', { weibo: weiboData, user: userData }

      totalPages = Math.cell( total_weibo / params.count )
      return if params.page is totalPages
      fetchMore()

    
  sync: (req, res, next) ->
  
  login: (req, res, next) ->
    if req.query.redirect?
      req.session.redirect = req.query.redirect
    oa = new OAuth config.request_token_url, config.access_token_url,
      config.api_key, config.api_secret, "1.0", null, "HMAC-SHA1"

    oa.getOAuthRequestToken (err, oauth_token, oauth_token_secret, results) ->
      return res.send 500, error: err if err?
      req.session.oa = oa
      req.session.oauth_token = oauth_token
      req.session.oauth_token_secret = oauth_token_secret
      res.redirect config.authorize_url +
        "?oauth_token=" + oauth_token +
        "&oauth_callback=http://" + req.headers['host'] + "/callback"

  callback: (req, res, next) ->
    oa = new OAuth config.request_token_url, config.access_token_url,
      config.api_key, config.api_secret, "1.0", null, "HMAC-SHA1"

    oa.getOAuthAccessToken req.session.oauth_token,
      req.session.oauth_token_secret,
      req.param('oauth_verifier'),
      (err, oauth_access_token, oauth_access_token_secret, results) ->
        return res.send 500, { error: JSON.stringify(err) } if err?
        req.session.oauth_access_token = oauth_access_token
        req.session.oauth_access_token_secret = oauth_access_token_secret

        res.redirect req.session.redirect ? '/'
