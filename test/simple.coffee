#should = require 'should'
helper = require './helper'
Weibo  = require '../lib/weibo'

describe "Login with given credential", ->

  before ->

  it 'should log in', (done) ->
    client = new Weibo
    done()
