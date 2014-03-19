#!/usr/bin/env ruby

# Copyright 2006-2012 Michel Casabianca <michel.casabianca@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rubygems'
$:.unshift(File.dirname(__FILE__))
require 'tmp_test_case'
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'bee_context'

class TestBeeContext < TmpTestCase

  def setup
    super
    @context = Bee::Context.new()
  end

  def test_properties
    # test that there are no properties after creation
    expected = []
    actual = @context.properties
    assert_equal(expected, actual)
  end

  def test_set_property
    # set property and check that it appears in context properties
    @context.set_property('foo', 1)
    expected = ['foo']
    actual = @context.properties
    assert_equal(expected, actual)
    # set another property and check it was added to the list
    @context.set_property('bar', 2)
    expected = ['bar', 'foo']
    actual = @context.properties.sort
    assert_equal(expected, actual)
  end

  def test_set_property_overwrite
    # test that we can redefine a property
    @context.set_property('foo', 1)
    @context.set_property('foo', 2)
  end

  def test_get_property
    # test we can get a property we just set, for different types
    expected = 1
    @context.set_property('foo', expected)
    actual = @context.get_property('foo')
    assert_equal(expected, actual)
    expected = 'abc'
    @context.set_property('foo', expected)
    actual = @context.get_property('foo')
    assert_equal(expected, actual)
    expected = true
    @context.set_property('foo', expected)
    actual = @context.get_property('foo')
    assert_equal(expected, actual)
  end

  def test_get_property_error
    # test that unset property raise an error
    assert_raise(Bee::Util::BuildError) do
      @context.get_property('bar')
    end
    # test that unset property raise an error
    assert_raise(Bee::Util::BuildError) do
      @context.get_property('raise "TEST"')
    end
  end

  def test_evaluate_script
    # Test that a simple script runs and returns the appropriate value
    script = "'TEST'"
    expected = 'TEST'
    actual = @context.evaluate_script(script)
    assert_equal(expected, actual)
    # test that a script can raise an exception
    assert_raise(Bee::Util::BuildError) do
      @context.evaluate_script('error "TEST"')
    end
  end

  def test_evaluate_object
    # nil: must evaluate to nil
    expected = nil
    actual = @context.evaluate_object(nil)
    assert_equal(expected, actual)
    # string: return value with property references replaced
    expected = "This is a test!"
    actual = @context.evaluate_object(expected)
    assert_equal(expected, actual)
    @context.set_property(:foo, 'bar')
    expected = 'This is bar!'
    actual = @context.evaluate_object('This is #{foo}!')
    assert_equal(expected, actual)
    # symbol: replace with property value
    expected = 'bar'
    actual = @context.evaluate_object(:foo)
    assert_equal(expected, actual)
    # array: return array with elements evaluated
    expected = [1, 2, 3]
    actual = @context.evaluate_object([1, 2, 3])
    assert_equal(expected, actual)
    expected = ['a', 'b', 'bar']
    actual = @context.evaluate_object(['a', 'b', :foo])
    assert_equal(expected, actual)
    # hash: return hash with keys and values evaluated
    expected = { 1 => 'bar', 'bar' => 2 }
    actual = @context.evaluate_object({ 1 => :foo, '#{foo}' => 2 })
    assert_equal(expected, actual)
    # complex: symbol referencing an array
    expected = [1, 2, 3]
    @context.set_property('int', 3)
    @context.set_property('array', [1, 2, :int])
    actual = @context.evaluate_object(:array)
    assert_equal(expected, actual)
  end

  def test_evaluate_object_error
    # string: raise an exception
    assert_raise(Bee::Util::BuildError) do
      @context.evaluate_object('#{raise "TEST"}')
    end
    # property not set
    assert_raise(Bee::Util::BuildError) do
      @context.evaluate_object(:toto)
    end
    # property not set in a string
    assert_raise(Bee::Util::BuildError) do
      @context.evaluate_object('#{toto} tutu')
    end
  end

  def test_constructor
    # test that all properties are defined
    properties = {
      :foo => 'foo #{bar}',
      :bar => 'bar',
    }
    context = Bee::Context.new(properties)
    context.evaluate
    expected = ['bar', 'base', 'foo', 'here']
    actual = context.properties.sort
    assert_equal(expected, actual)
    # test values for foo and bar
    expected = 'foo bar'
    actual = context.get_property('foo')
    assert_equal(expected, actual)
    expected = 'bar'
    actual = context.get_property('bar')
    assert_equal(expected, actual)
    # test property name can collide with context functions
    properties = {:test => 'test'}
    Bee::Context.new(properties)
    # test with a script
    script = write_tmp_file('build.rb', "foo = 'foo'; bar = 123")
    context = Bee::Context.new({}, [script])
    context.evaluate
    expected = ['foo', 123]
    actual = [context.get_property('foo'), context.get_property('bar')]
    assert_equal(expected, actual)
    # test with properties and a script
    properties = {:foo => 'foo', :bar => 123}
    script = write_tmp_file('build.rb', "foo = 'bar'")
    context = Bee::Context.new(properties, [script])
    context.evaluate
    expected = ['foo', 123]
    actual = [context.get_property('foo'), context.get_property('bar')]
    assert_equal(expected, actual)
  end

  def test_constructor_error
    # test circular reference
    properties = {
      :foo => '#{foo}',
    }
    assert_raise(Bee::Util::BuildError) do
      context = Bee::Context.new(properties)
      context.evaluate
    end
    properties = {
      :foo => '#{bar}',
      :bar => '#{foo}',
    }
    assert_raise(Bee::Util::BuildError) do
      context = Bee::Context.new(properties)
      context.evaluate
    end
    properties = {
      :foo => '#{bar}',
      :bar => '#{baz}',
      :baz => '#{foo}',
    }
    assert_raise(Bee::Util::BuildError) do
      context = Bee::Context.new(properties)
      context.evaluate
    end
  end

end
