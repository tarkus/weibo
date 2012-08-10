config  = require __dirname + '/../config'
{OAuth} = require 'oauth'

class Weibo

  constructor: ->
    oa = new OAuth "http://api.t.sina.com.cn/oauth/request_token",
      "http://api.t.sina.com.cn/oauth/access_token",
      config.api_key, config.api_secret,
      "1.0", null, "HMAC-SHA1"
    oa.getOAuthRequestToken (err, oauth_token, oauth_token_secret, results) ->
      return console.log err if err?
      console.log oauth_token, oauth_token_secret, results
      oa.getOAuthAccessToken oauth_token, oauth_token_secret,
        (err, oauth_access_token, oauth_access_secret, access_results) ->
          return console.log err, access_results if err?
          console.log oauth_access_token, oauth_access_secret


module.exports = Weibo
