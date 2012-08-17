{OAuth} = require 'oauth'
config  = require '../config'
helper  = require '../lib/helper'
qs      = require 'querystring'

Weibo   = require '../models/weibo'
User    = require '../models/user'

halt = ->
  console.log arguments.join ' '
  
now = exports.now = ->
  Math.round(Date.now() / 1000)


createClient = (req) ->
  return false unless req.session.oa?
  return new OAuth req.session.oa._requestUrl,
    req.session.oa._accessUrl,
    req.session.oa._consumerKey,
    req.session.oa._consumerSecret,
    req.session.oa._version,
    req.session.oa._authorize_callback,
    req.session.oa._signatureMethod

module.exports = (app) ->
  
  index: (req, res, next) ->
                
    page = _page = req.query.page ? 1
    page_size = 50
    oa = createClient(req)

    fetchUser = (next) ->
      params = uid: config.user_id

      oa.get config.api_baseurl + 'users/show.json?' + qs.stringify(params),
        req.session.oauth_access_token, req.session.oauth_access_token_secret,
        (err, data, result) ->
          if err? and err.statusCode is 403
            return setTimeout ->
              fetchUser next
            , 6000
          return console.log err if err
          try
            json = JSON.parse(data)
          catch e
            return console.log e
          next(json)

    storeUser = exports.storeUser = (data, next) ->
      user = new User
      user.prop
        user_id: parseInt(data.id)
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
            @save (err) ->
              return halt "storeUser::update", err if err
              return next?(@)

    getUser = (next) ->
      User.find user_id: config.user_id, (err, ids) ->
        if ids.length < 1
          return fetchUser (json) -> storeUser json, -> getUser next
        #fetchUser (json) -> storeUser json
        User.load parseInt(ids[0]), (err, props) ->
          return halt if err?
          next @prop('raw')

    fetchWeibo = (params, next) ->
      if typeof params is 'function'
        next = params
        params = null
      defaults =
        uid: config.user_id
        trim_user: 1
        page: _page
      params = params or defaults
      params = defaults extends params
      params.count = page_size

      oa.get config.api_baseurl + 'statuses/user_timeline.json?' + qs.stringify(params),
        req.session.oauth_access_token, req.session.oauth_access_token_secret,
        (err, data, result) ->
          if err? and err.statusCode is 403
            return setTimeout ->
              fetchUser next
            , 6000
          return console.log err if err
          try
            json = JSON.parse(data)
          catch e
            return console.log e
          next?(json.statuses)

    storeWeibo = exports.storeWeibo = (data, next) ->
      return halt 'storeWeibo', data unless data?
      counter = 0
      weiboData = []
      for entry in data
        weibo = new Weibo
        weibo.prop
          user_id: parseInt(entry.user_id)
          weibo_id: parseInt(entry.id)
          raw: entry

        weibo.save (err) ->
          unless err
            counter++
            weiboData.push @prop('raw')
            if counter is data.length
              return next?(weiboData)
            return weiboData

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
              @save (err) ->
                return halt 'storeWeibo::update', err if err?
                counter++
                weiboData.push @prop('raw')
                return next?(weiboData) if counter is data.length

    getWeibo = (userData, next) ->
      Weibo.sort
        field: 'weibo_id'
        direction: 'DESC'
        limit: [(_page - 1) * page_size, page_size]
      , (err, ids) ->
        if not ids or ids.length < 1
          return fetchWeibo (json) -> storeWeibo json, (weiboData) ->
            next?(userData, weiboData)
        #fetchWeibo (json) -> storeWeibo json
        weiboData = []
        counter = 0
        for id in ids
          Weibo.load parseInt(id), (err, props) ->
            return halt 'getWeibo::load', err if err
            counter++
            weiboData.push @prop('raw')
            next?(userData, weiboData) if counter is ids.length

    updateClient = ->
      unless app.socket?
        return setTimeout ->
          updateClient()
        , 6000
      ###
      app.socket.emit 'fetching',
        current: _page
        total: res.locals.pager.max
      return if page is res.locals.pager.max
      _page++
      setTimeout ->
        updateClient()
      , 3000
      return
      ###
      getWeibo null, ->
        app.socket.emit 'fetching',
          current: _page
          total: res.locals.pager.max
        return if page is res.locals.pager.max
        _page++
        setTimeout ->
          updateClient()
        , 6000

    getUser (userData) -> getWeibo userData, (userData, weiboData) ->

      res.locals.pager = helper.pager
        page: page
        size: page_size
        total: userData.statuses_count
        range: 9

      return res.render 'index',
        weibo: weiboData
        user: userData
        weiboText: (text) ->
          text.replace(/(http:\/\/[^\/]+\/\w+)/g, "<a href='$1'>$1</a>").
            replace(/@([^:|：| |”|，|,|。]+)([:|：| |”|，|,|。])/g, "<a href='http://weibo.com/n/$1'>@$1</a>$2")

      _page = 1
      updateClient()
  
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
