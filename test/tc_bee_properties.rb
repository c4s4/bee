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
require 'test/unit'
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'bee_properties'

class TestBeeProperties < Test::Unit::TestCase

  def setup
    @expressions = {:foo => 'bar', :spam => 'eggs'}
    @properties = Bee::Properties.new(@expressions)
  end

  def test_constructor
    # test that expressions are correct
    expected = @expressions
    actual = @properties.expressions
    assert_equal(expected, actual)
    # test that we raise a error when setting resreved properties
    assert_raise(Bee::Util::BuildError) do
      Bee::Properties.new({:base => 'base'})
    end
    assert_raise(Bee::Util::BuildError) do
      Bee::Properties.new({'base' => 'base'})
    end
  end

  def test_constructor_error
    assert_raise(Bee::Util::BuildError) do
      Bee::Properties.new('test')
    end
  end

  def test_write
    @properties.overwrite({:toto => 'titi'})
    expected = {:foo => 'bar', :spam => 'eggs', :toto => 'titi'}
    actual = @properties.expressions
    assert_equal(expected, actual)
    # test that overwriting raises an error
    assert_raise(Bee::Util::BuildError) do
      @properties.write({:foo => 'toto'})
    end
  end

  def test_write_reserved
    # test that we can't set resreved properties (base and here)
    assert_raise(Bee::Util::BuildError) do
      @properties.write({:base => 'base'})
    end
    assert_raise(Bee::Util::BuildError) do
      @properties.write({:here => 'here'})
    end
    assert_raise(Bee::Util::BuildError) do
      @properties.write({:base => 'base', :here => 'here'})
    end
  end

  def test_overwrite
    @properties.overwrite({:foo => 'toto'})
    expected = {:foo => 'toto', :spam => 'eggs'}
    actual = @properties.expressions
    assert_equal(expected, actual)
  end

  def test_extend
    @properties.extend({:foo => 'toto', :baz => 'titi'})
    expected = {:foo => 'bar', :spam => 'eggs', :baz => 'titi'}
    actual = @properties.expressions
    assert_equal(expected, actual)
  end

  def test_defaults
    @properties.defaults({:base => 'base'})
    expected = {:base => 'base', :foo => 'bar', :spam => 'eggs'}
    actual = @properties.expressions
    assert_equal(expected, actual)
  end

  def test_check_properties
    assert_raise(Bee::Util::BuildError) do
      @properties.send(:check_properties, {:base => 'foo'})
    end
  end

end
