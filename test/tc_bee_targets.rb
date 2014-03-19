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
$:.unshift(File.expand_path(File.dirname(__FILE__)))
require 'tmp_test_case'
require 'test_build'
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'bee_targets'

# Test case for Bee.
class TestBeeTargets < TmpTestCase

  def setup()
    @build = TestBuild.new()
    @targets = Bee::Targets.new(@build)
    @script = [{'print' => 'This is a test!'}]
    @target = {
      'target' => 'test',
      'description' => 'Test description',
      'script' => @script,
    }
    @targets.add(@target)
  end

  def test_add
    # nominal case
    assert_equal(['test'], @targets.hash.keys())
    target = @targets.hash['test'][0]
    assert_equal('test', target.name)
    assert_equal('Test description', target.description)
    assert_equal([], target.depends)
    assert_equal(@script, target.script)
    # error case
    assert_raise(Bee::Util::BuildError) { @targets.add('test') }
    assert_raise(Bee::Util::BuildError) { @targets.add(@target) }
  end

  def test_extend
    @targets.add({'target' => 'eggs'})
    parent = Bee::Targets.new(nil)
    parent.add({'target' => 'eggs', 'description' => 'New description'})
    parent.add({'target' => 'test', 'description' => 'Desc', 'script' => 'Hello from super!'})
    parent.add({'target' => 'toto', 'description' => 'Hello', 'depends' => 'spam'})
    @targets.extend(parent)
    assert_equal(['eggs', 'test', 'toto'], @targets.hash.keys.sort)
    assert_equal(2, @targets.hash['eggs'].length)
    assert_equal('New description', @targets.hash['eggs'][0].description)
    assert_equal(2, @targets.hash['test'].length)
    assert_equal('Test description', @targets.hash['test'][1].description)
    assert_equal([], @targets.hash['test'][1].depends)
    assert_equal(1, @targets.hash['toto'].length)
    assert_equal(['spam'], @targets.hash['toto'][0].depends)
  end

  def test_run_target
    # nominal case
    @targets.run_target('test', false)
    assert_equal("This is a test!\n", @build.listener.output)
    assert_equal(['test'], @targets.already_run)
    @build.listener.formatter.clear
    @targets.run_target('test', false)
    assert_equal("", @build.listener.output)
    @build.listener.formatter.clear
    @targets.already_run.clear
    @targets.run_target('test', true)
    assert_equal("", @build.listener.output)
    # error case : unknown target
    assert_raise(Bee::Util::BuildError) { @targets.run_target('unknown') }
  end

  def test_run
    # nominal case
    @targets.run(['test'], false)
    assert_equal("This is a test!\n", @build.listener.output)
    assert_equal([], @targets.already_run)
    @build.listener.formatter.clear
    @targets.run(['test'], false)
    assert_equal("This is a test!\n", @build.listener.output)
    assert_equal([], @targets.already_run)
    @build.listener.formatter.clear
    @targets.run(['test'], true)
    assert_equal("", @build.listener.output)
    assert_equal([], @targets.already_run)
    # error case
    assert_raise(Bee::Util::BuildError) { @targets.run(['unknown'], false) }
  end

  def test_call_super
    # error case : no super to call
    target = @targets.hash['test'].last
    assert_raise(Bee::Util::BuildError) { @targets.call_super(target, false) }
    # nominal case
    parent = Bee::Targets.new(nil)
    parent.add({'target' => 'test', 'script' => [{'print' => 'Hello from super!'}]})
    @targets.extend(parent)
    target = @targets.hash['test'].last
    @targets.call_super(target, false)
    assert_equal("Hello from super!\n", @build.listener.output)
  end

  def test_is_last
    # nominal cases
    parent = Bee::Targets.new(nil)
    parent.add({'target' => 'test', 'script' => [{'print' => 'Hello from super!'}]})
    @targets.extend(parent)
    target = @targets.hash['test'].last
    assert(@targets.is_last(target))
    target = @targets.hash['test'].first
    assert_equal(false, @targets.is_last(target))
  end

  def test_description
    @targets.add({'target' => 'foo', 'description' => 'Foo description', 'depends' => 'bar'})
    expected = {"test" => "Test description", "foo"=> "Foo description [bar]"}
    actual = @targets.description
    assert_equal(expected, actual)
  end

end
