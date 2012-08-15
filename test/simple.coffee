#should = require 'should'
testHelper = require './helper'
helper = require __dirname + '/../lib/helper'

describe "Test helpers", ->

  before ->

  it 'printObject', (done) ->
    obj =
      foo: 'bar'
      text: '中文'
      ###
      deeper:
        level: 1
        deeper:
          level: 2
      ###

    console.log "\n" + helper.printObject(obj)
    helper.printObject(obj).should.eql """
      "foo": "bar", 
      "text": "中文"
    """
    done()
