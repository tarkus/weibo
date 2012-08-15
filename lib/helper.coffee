Weibo   = require '../models/weibo'
User    = require '../models/user'

halt = ->
  console.log arguments.join ' '
  
now = exports.now = ->
  Math.round(Date.now() / 1000)

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
        @save (err) ->
          return halt "storeUser::update", err if err
          return next?()

storeWeibo = exports.storeWeibo = (data, next) ->
  total = Object.keys(data).length
  count = 0
  for id, entry of data
    weibo = new Weibo
    weibo.prop
      user_id: entry.user_id ? entry.user.id
      weibo_id: entry.id
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
            updated_at: now()
          @save (err) ->
            return halt 'storeWeibo::update', err if err?
            count++
            return next?() if total is count
