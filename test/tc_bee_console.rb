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
require 'stringio'
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'bee_console'
$:.unshift(File.expand_path(File.dirname(__FILE__)))
require 'tmp_test_case'

class TestBeeConsole < TmpTestCase
  
  def test_parse_command_line
    old_beeopt = ENV['BEEOPT']
    ENV['BEEOPT'] = ''
    arguments = ['-V', '-h', '-b', '-k', 'task', '-e', 'template',
      '-p', 'name=value', '-n', '-v', '-s', 'style', '-c', '-w', '-f', 'file',
      '-r', '-l', '-R', 'resource', '-a', '-o', '-x', '-y', 'targets']
    actual = Bee::Console.parse_command_line(arguments)
    expected = [true, true, true, true, 'task', true, 'template',
      {'name'=>'value'}, true, true, 'style', false, 'file',
      true, true, 'resource', true, true, true, true, ['targets']]
    assert_equal(expected, actual)
    ENV['BEEOPT'] = old_beeopt
  end

  def test_parse_properties
    # nominal case string
    expected = 'name', 'value'
    actual = Bee::Console::parse_property('name=value')
    assert_equal(expected, actual)
    # nominal case integer
    expected = 'name', 42
    actual = Bee::Console::parse_property('name=42')
    assert_equal(expected, actual)
    # nominal case float
    expected = 'name', 1.23
    actual = Bee::Console::parse_property('name=1.23')
    assert_equal(expected, actual)
    # nominal case nil
    expected = 'name', nil
    actual = Bee::Console::parse_property('name=~')
    assert_equal(expected, actual)
    actual = Bee::Console::parse_property('name=null')
    assert_equal(expected, actual)
    # nominal case date
    # should work: YAML parser doesn't recognizes dates?
    #expected = 'name', DateTime.new(2001, 11, 23, 14, 15, 27)
    #actual = Bee::Console::parse_property('name=2001-11-23T14:15:27')
    #assert_equal(expected, actual)
    # nominal case list
    expected = 'name', ['foo', 'bar']
    actual = Bee::Console::parse_property('name=[foo, bar]')
    assert_equal(expected, actual)
    # nominal case map
    expected = 'name', {'foo'=>'bar'}
    actual = Bee::Console::parse_property('name={foo: bar}')
    assert_equal(expected, actual)
    # error case: no = sign
    assert_raise(RuntimeError) { Bee::Console::parse_property('foo') }
  end

  def test_start_command_line
    # error in property
    assert_output(/^ERROR: parsing command line: Error parsing property 'foo': No = sign \(should be 'name=value'\)$/) do
      assert_raise(SystemExit) { Bee::Console::start_command_line(['-p', 'foo']) }
    end
    # error in style
    assert_output(/^ERROR: bad format string 'foo'$/) do
      assert_raise(SystemExit) { Bee::Console::start_command_line(['-s', 'foo']) }
    end
    # test logo
    assert_output(/#{Bee.version}.*?http:\/\/bee.rubyforge.org/) do
      Bee::Console::start_command_line(['-l', '-h'])
    end
    # test version
    assert_output(/^#{Bee.version}$/) do
      Bee::Console::start_command_line(['-V'])
    end
    # test help
    assert_output(/^Usage: bee \[options\] \[targets\]/) do
      Bee::Console::start_command_line(['-h'])
    end
    if bee_available?
      # test help task
      assert_output(/Print a message on console./) do
        Bee::Console::start_command_line(['-k', 'echo'])
      end
      # test help template
      assert_output(/This script will generate a sample Ruby source file./) do
        Bee::Console::start_command_line(['-e', 'source'])
      end
      # test list tasks
      assert_output(/^bee .*?cat .*?cd .*?chmod .*?chown .*?copy/) do
        Bee::Console::start_command_line(['-x'])
      end
      # test list templates
      assert_output(/^application .*?package .*?script .*?sinatra .*?source .*?xmlrpc/) do
        Bee::Console::start_command_line(['-y'])
      end
    end
    # test print options
    assert_output(/--version/) do
      Bee::Console::start_command_line(['-o'])
    end
  end

  def test_template
    build = mock
    Bee::Util.expects(:find_template).with('foo').returns('foo')
    Bee::Build.expects(:load).returns(build)
    build.expects(:run)
    Bee::Console::start_command_line(['-t', 'foo'])
  end

  def test_unexpected_error
    build = mock
    Bee::Build.expects(:load).returns(build)
    build.expects(:run).raises(Exception, 'TEST')
    assert_output(/ERROR.*?: TEST/) do
      assert_raise(SystemExit) { Bee::Console::start_command_line([]) }
    end
  end
  
end
