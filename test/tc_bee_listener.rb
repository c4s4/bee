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
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'bee_listener'
require 'bee_util'
require 'test/unit'

class TestBeeConsoleListener < Test::Unit::TestCase

  def test_build_success
    start_time = Time.now
    formatter = BeeConsoleFormatterTest.new
    listener = Bee::Listener.new(formatter)
    listener.start('build', 'dry_run')
    listener.target('target')
    listener.task('task')
    listener.stop()
    duration = Time.now - start_time
    expected = [
      ["print_build_started", "build", "dry_run"],
      ["print_target", "target"],
      ["print_task", "task"],
      ["print_build_finished", 0],
    ]
    actual = formatter.called_methods
    assert_equal(expected, actual)
    assert_in_delta(duration, listener.duration, 0.01)
  end

  def test_build_error
    start_time = Time.now
    formatter = BeeConsoleFormatterTest.new
    listener = Bee::Listener.new(formatter)
    listener.start('build', 'dry_run')
    listener.target('target')
    listener.task('task')
    listener.error(Bee::Util::BuildError.new('TEST'))
    listener.stop()
    duration = Time.now - start_time
    expected = [
      ["print_build_started", "build", "dry_run"],
      ["print_target", "target"],
      ["print_task", "task"],
      ["print_build_finished", 0],
    ]
    actual = formatter.called_methods
    assert_equal(expected, actual)
    assert_in_delta(duration, listener.duration, 0.01)
  end

  def test_build_recover
    start_time = Time.now
    formatter = BeeConsoleFormatterTest.new
    listener = Bee::Listener.new(formatter)
    listener.start('build', 'dry_run')
    listener.target('target')
    listener.task('task')
    listener.error('TEST')
    listener.recover()
    listener.stop()
    duration = Time.now - start_time
    expected = [
      ["print_build_started", "build", "dry_run"],
      ["print_target", "target"],
      ["print_task", "task"],
      ["print_build_finished", 0]
    ]
    actual = formatter.called_methods
    assert_equal(expected, actual)
    assert_in_delta(duration, listener.duration, 0.01)
    assert(listener.successful)
  end

end

################################################################################
#                    UTILITY FORMATTER TO RECORD CALLS                         #
################################################################################

class BeeConsoleFormatterTest

  attr_reader :called_methods
  attr_reader :verbose

  def initialize()
    @called_methods = []
    @verbose = false
  end

  def method_missing(method, *arguments, &block)
    @called_methods << [method.to_s] + arguments
  end

end
