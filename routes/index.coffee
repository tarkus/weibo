config  = require __dirname + '/../config'
{OAuth} = require 'oauth'

exports.index = (req, res) ->
  res.render 'index', { title: 'knock knock' }
    
exports.login = (req, res) ->
  console.log req.headers
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

exports.callback = (req, res) ->
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
