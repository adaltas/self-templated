
templated = require '../src'
{merge} = require 'mixme'

describe 'test', ->
  
  describe 'initialize', ->

    it 'parent level', ->
      templated
        key_inject: 'value inject'
        key_assert: '{{key_inject}}'
      .key_assert.should.eql 'value inject'

    it 'child level', ->
      templated
        key_inject: 'value inject'
        parent: key_assert: '{{key_inject}}'
      .parent.key_assert.should.eql 'value inject'
        
    it 'access twice the same key', ->
      # Note, fix a bug where the rendering only occured the first time
      res = templated
        keys:
          key_inject: 'value inject'
          key_assert: '{{keys.key_inject}}'
      res.keys.key_assert.should.eql 'value inject'
      res.keys.key_assert.should.eql 'value inject'

    it 'value of various types', ->
      res = templated
        templates:
          a_boolean_true: '{{values.a_boolean_true}}'
          a_boolean_false: '{{values.a_boolean_false}}'
          a_number: '{{values.a_number}}'
          a_null: '{{values.a_null}}'
          an_object: '{{{values.an_object}}}'
          a_string: '{{values.a_string}}'
          an_undefined: '{{values.an_undefined}}'
        values:
          a_boolean_true: true
          a_boolean_false: false
          a_number: 3.14
          a_null: null
          an_object: {a: 'b', toString: -> JSON.stringify @}
          a_string: 'a string'
          an_undefined: undefined
      , compile: true
      .templates.should.eql
        a_string: 'a string'
        a_boolean_true: 'true'
        a_boolean_false: 'false'
        a_number: '3.14'
        a_null: ''
        an_object: '{"a":"b"}'
        an_undefined: ''

  describe 'mutate', ->
    
    it 'does not mutate by default', ->
      source =
        keys:
          key_inject: 'value inject'
          key_assert: '{{keys.key_inject}}'
      templated source, mutate: false
      source.keys.key_assert.should.eql '{{keys.key_inject}}'
        
    it 'work on the input reference', ->
      source =
        keys:
          key_inject: 'value inject'
          key_assert: '{{keys.key_inject}}'
      templated source, mutate: true
      source.keys.should.eql
        key_inject: 'value inject'
        key_assert: '{{keys.key_inject}}'
      source.keys.key_assert.should.eql 'value inject'
        
    it 'access twice the same key', ->
      # Note, fix a bug where the rendering only occured the first time
      source =
        keys:
          key_inject: 'value inject'
          key_assert: '{{keys.key_inject}}'
      templated source, mutate: true
      source.keys.key_assert.should.eql 'value inject'
      source.keys.key_assert.should.eql 'value inject'
        
    it 'with partial', ->
      source =
        keys:
          key_inject: 'value inject'
          key_1: '{{keys.key_inject}}'
          key_2: '{{keys.key_inject}}'
      templated source,
        mutate: true
        partial: keys:
          key_1: true
          key_2: false
      source.keys.should.eql
        key_inject: 'value inject'
        key_1: '{{keys.key_inject}}'
        key_2: '{{keys.key_inject}}'
      source.keys.key_1.should.eql 'value inject'
      source.keys.key_2.should.eql '{{keys.key_inject}}'

  describe 'proxy', ->
    
    it 'set then retrieve values', ->
      # Note we used to have a bug where getting an object will result to
      # undefined after it was set
      obj = templated {toto: {}}
      obj.a_string = 'a value'
      obj.an_object = {}
      obj.a_string.should.eql 'a value'
      obj.an_object.should.eql {}
      obj.a_false_value = false
      obj.toto.a_false_value = false
      obj.toto = false
        
    it 'set element in proxy array', ->
      ## Fix error
      # `TypeError: 'set' on proxy: trap returned falsish for property '1'`
      # when `proxy.set` does not return true
      obj = templated
        key_inject: 'value inject'
        key_assert: [a: ['{{key_inject}}']]
      ,
        array: true
      obj.key_assert.push b: {}
      obj.key_assert.should.eql [
        { a: ['{{key_inject}}'] }
        { b: {} }
      ]
      obj.key_assert[0].a.push 'ok'
      obj.key_assert[0].a.should.eql [
        '{{key_inject}}'
        'ok'
      ]

  describe 'inject', ->

    it 'parent level', ->
      templated
        key_1: 'value 1'
        key_assert: '{{key_1}}, {{key_2}}'
        key_2: 'value 2'
      .key_assert.should.eql 'value 1, value 2'

    it 'child level', ->
      templated
        parent_1: key_1: 'value 1'
        key_assert: '{{parent_1.key_1}}, {{parent_2.key_2}}'
        parent_2: key_2: 'value 2'
      .key_assert.should.eql 'value 1, value 2'
    
    it 'indirect references', ->
      templated
        key_assert: '{{level_parent_1.level_key_1}}'
        level_parent_1: level_key_1: 'value 1, {{level_parent_2.level_key_2}}'
        level_parent_2: level_key_2: 'value 2'
        parent_2: key_2: 'value 2'
      .key_assert.should.eql 'value 1, value 2'
  
  describe 'conflict', ->
    
    it 'direct circular references', ->
      ( ->
        templated
          key_1: '{{key_2}}'
          key_2: '{{key_1}}'
        .key_1
      ).should.throw 'Circular Reference: graph is ["key_1"] -> ["key_2"] -> ["key_1"]'
        
    it 'indirect circular references', ->
      ( ->
        templated
          key_1: '{{key_2}}'
          key_pivot: '{{key_1}}'
          key_2: '{{key_pivot}}'
        .key_1
      ).should.throw 'Circular Reference: graph is ["key_1"] -> ["key_2"] -> ["key_pivot"] -> ["key_1"]'

  describe 'option partial', ->
  
    it 'root', ->
      context = templated
        key_1: 'value 1, {{key_3}}'
        key_2: 'value 2, {{key_3}}'
        key_3: 'value 3, {{key_4}}'
        key_4: 'value 4'
      , partial: key_1: true
      context.key_1.should.eql 'value 1, value 3, {{key_4}}'
      context.key_2.should.eql 'value 2, {{key_3}}'
            
    it 'child', ->
      context = templated
        parent:
          key_1: 'value 1, {{key_3}}'
          key_2: 'value 2, {{key_3}}'
        key_3: 'value 3, {{key_4}}'
        key_4: 'value 4'
      , partial: parent: key_1: true
      context.parent.key_1.should.eql 'value 1, value 3, {{key_4}}'
      context.parent.key_2.should.eql 'value 2, {{key_3}}'
            
    it 'child with array index', ->
      context = templated
        key_1: 'value 1'
        key_2: [
          { key_2_1: 'value 2 1, {{key_1}}' }
        ,
          { key_2_2: 'value 2 2, {{key_1}}' }
        ]
      ,
        partial: key_2: 1: key_2_2: true
        array: true
      context.key_2[0].key_2_1.should.eql 'value 2 1, {{key_1}}'
      context.key_2[1].key_2_2.should.eql 'value 2 2, value 1'
            
    it 'cascade in child', ->
      context = templated
        parent:
          child: key_1: 'value 1, {{key_3}}'
          key_2: 'value 2, {{key_3}}'
        key_3: 'value 3, {{key_4}}'
        key_4: 'value 4'
      , partial: parent: child: true
      context.parent.child.key_1.should.eql 'value 1, value 3, {{key_4}}'
      context.parent.key_2.should.eql 'value 2, {{key_3}}'
            
    it 'cascade in child with array index', ->
      context = templated
        key_1: 'value 1'
        key_2: [
          { key_2_1: 'value 2 1, {{key_1}}' }
        ,
          { key_2_2: 'value 2 2, {{key_1}}' }
        ]
      ,
        partial: key_2: 1: true
        array: true
      context.key_2[0].key_2_1.should.eql 'value 2 1, {{key_1}}'
      context.key_2[1].key_2_2.should.eql 'value 2 2, value 1'
            
    it 'with compile', ->
      context = templated
        parent: key_1: 'value 1, {{key_3}}'
        key_2: 'value 2, {{key_3}}'
        key_3: 'value 3, {{key_4}}'
        key_4: 'value 4'
      , compile: true, partial: parent: key_1: true
      context.parent.key_1.should.eql 'value 1, value 3, {{key_4}}'
      context.key_2.should.eql 'value 2, {{key_3}}'

  describe 'option array', ->
    
    it 'desactivated by default', ->
      templated
        key_inject: 'value inject'
        key_assert: ['{{key_inject}}']
      .key_assert[0].should.eql '{{key_inject}}'
    
    it 'simple element', ->
      templated
        key_inject: 'value inject'
        key_assert: ['{{key_inject}}']
      ,
        array: true
      .key_assert[0].should.eql 'value inject'
        
    it 'array in object in array', ->
      templated
        key_inject: 'value inject'
        key_assert: [a: ['{{key_inject}}']]
      ,
        array: true
      .key_assert[0].a[0].should.eql 'value inject'
        
    it 'with compile', ->
      templated
        key_inject: 'value inject'
        key_assert: ['{{key_inject}}']
      ,
        array: true
        compile: true
      .should.eql
        key_inject: 'value inject'
        key_assert: [ 'value inject' ]
