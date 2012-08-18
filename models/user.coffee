{Nohm} = require 'nohm'

module.exports = Nohm.model 'User',
  idGenerator: 'increment'

  properties:
    user_id:
      type: 'integer'
      unique: true
      index: true
    name:
      type: 'string'
    fetched_count:
      type: 'integer'
      defaultValue: null
    raw:
      type: 'json'
    updated_at:
      type: 'timestamp'
      defaultValue: ->
        Math.round(Date.now() / 1000)
