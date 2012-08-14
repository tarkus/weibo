{Nohm} = require 'nohm'

module.exports = Nohm.model 'Weibo',
  idGenerator: 'increment'

  properties:
    user_id:
      type: 'integer'
      index: true
    weibo_id:
      type: 'integer'
      index: true
    raw:
      type: 'json'
    updated_at:
      type: 'timestamp'
      defaultValue: new Date()
