{Nohm} = require 'nohm'

module.exports = Nohm.model 'Weibo',
  idGenerator: 'increment'

  properties:
    user_id:
      type: 'integer'
      index: true
    weibo_id:
      type: 'integer'
      unique: true
      index: true
    raw:
      type: 'json'
    updated_at:
      type: 'timestamp'
      defaultValue: ->
        Math.round(Date.now() / 1000)
