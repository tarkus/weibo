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
      index: true
    raw:
      type: 'json'
    updated_at:
      type: 'timestamp'
      defaultValue: new Date()
