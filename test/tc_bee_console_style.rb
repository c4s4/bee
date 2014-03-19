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
require 'bee_console_style'

# Test case for console formatter.
class TestBeeConsoleStyle < Test::Unit::TestCase

  def test_constructor
    # test nominal case
    string = 'll:66,lc:*,ts:bright,tf:yellow,tb:green,ks:dim,kf:blue,kb:white,'+
      'ss:bright,sf:green,sb:red,es:blink,ef:red,eb:magenta'
    style = Bee::Console::Style.new(string)
    assert_equal(66, style.line_length)
    assert_equal('*', style.line_character)
    assert_equal(:bright, style.target_style)
    assert_equal(:yellow, style.target_foreground)
    assert_equal(:green, style.target_background)
    assert_equal(:dim, style.task_style)
    assert_equal(:blue, style.task_foreground)
    assert_equal(:white, style.task_background)
    assert_equal(:bright, style.success_style)
    assert_equal(:green, style.success_foreground)
    assert_equal(:red, style.success_background)
    assert_equal(:blink, style.error_style)
    assert_equal(:red, style.error_foreground)
    assert_equal(:magenta, style.error_background)
    # test default case
    style = Bee::Console::Style.new()
    assert_equal(nil, style.line_length)
    assert_equal('-', style.line_character)
    assert_equal(nil, style.target_style)
    assert_equal(nil, style.target_foreground)
    assert_equal(nil, style.target_background)
    assert_equal(nil, style.task_style)
    assert_equal(nil, style.task_foreground)
    assert_equal(nil, style.task_background)
    assert_equal(nil, style.success_style)
    assert_equal(nil, style.success_foreground)
    assert_equal(nil, style.success_background)
    assert_equal(nil, style.error_style)
    assert_equal(nil, style.error_foreground)
    assert_equal(nil, style.error_background)
    # test color case
    style = Bee::Console::Style.new(nil, true)
    assert_equal(nil, style.line_length)
    assert_equal('-', style.line_character)
    assert_equal(nil, style.target_style)
    assert_equal(:yellow, style.target_foreground)
    assert_equal(nil, style.target_background)
    assert_equal(nil, style.task_style)
    assert_equal(:blue, style.task_foreground)
    assert_equal(nil, style.task_background)
    assert_equal(:bright, style.success_style)
    assert_equal(:green, style.success_foreground)
    assert_equal(nil, style.success_background)
    assert_equal(:bright, style.error_style)
    assert_equal(:red, style.error_foreground)
    assert_equal(nil, style.error_background)
    # test passing wrong style string
    assert_raise(RuntimeError) { Bee::Console::Style.new('toto') }
    # test passing wrong style hash
    assert_raise(RuntimeError) { Bee::Console::Style.new({'error_style' => :bright}) }
    assert_raise(RuntimeError) { Bee::Console::Style.new({:line_length => '3'}) }
    assert_raise(RuntimeError) { Bee::Console::Style.new({:line_character => '--'}) }
    assert_raise(RuntimeError) { Bee::Console::Style.new({:error_style => 'bright'}) }
    assert_raise(RuntimeError) { Bee::Console::Style.new({:error_style => :toto}) }
    assert_raise(RuntimeError) { Bee::Console::Style.new({:error_foreground => :toto}) }
  end

  def test_style
    # test nominal cases
    style = Bee::Console::Style.new(nil, true)
    expected = "\e[33mtest\e[0m"
    actual = style.style('test', :target)
    assert_equal(expected, actual)
    expected = "\e[34mtest\e[0m"
    actual = style.style('test', :task)
    assert_equal(expected, actual)
    expected = "\e[1;32mtest\e[0m"
    actual = style.style('test', :success)
    assert_equal(expected, actual)
    expected = "\e[1;31mtest\e[0m"
    actual = style.style('test', :error)
    assert_equal(expected, actual)
    # test error case
    assert_raise(RuntimeError) { style.style('test', :toto) }
  end

end
