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
require 'bee_target'
require 'bee_build'

class TestBeeTarget < TmpTestCase

  def test_constructor
    # nominal case
    object = {
      'target' => 'test',
      'depends' => ['foo', 'bar'],
      'description' => 'Target description',
      'script' => [ {'print' => 'Hello World!'} ]
    }
    target = Bee::Target.new(object, nil)
    self.assert_equal('test', target.name)
    self.assert_equal(['foo', 'bar'], target.depends)
    self.assert_equal('Target description', target.description)
    self.assert_equal([ {'print' => 'Hello World!'} ], target.script)
    # nominal case with no depends, description and script
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, nil)
    self.assert_equal('test', target.name)
    self.assert_equal([], target.depends)
    self.assert_equal(nil, target.description)
    self.assert_equal([], target.script)
    # nominal case with a single dependency
    object = { 'target' => 'test', 'depends' => 'foo' }
    target = Bee::Target.new(object, nil)
    self.assert_equal('test', target.name)
    self.assert_equal(['foo'], target.depends)
    self.assert_equal(nil, target.description)
    self.assert_equal([], target.script)
    # nominal case with a single line script
    object = { 'target' => 'test', 'script' => 'foo' }
    target = Bee::Target.new(object, nil)
    self.assert_equal('test', target.name)
    self.assert_equal([], target.depends)
    self.assert_equal(nil, target.description)
    self.assert_equal(['foo'], target.script)
    # error case with no name
    object = { 'target' => nil }
    assert_raise(Bee::Util::BuildError) { target = Bee::Target.new(object, nil) }
  end

  def test_run
    # check that we call dependencies
    listener = mock('listener')
    build = mock('listener')
    targets = mock('targets')
    targets.expects(:run_target).with('foo', false)
    targets.expects(:run_target).with('bar', false)
    targets.expects(:build).returns(build)
    build.expects(:listener).returns(listener)
    targets.expects(:is_last).returns(true)
    targets.expects(:build).returns(build)
    build.expects(:listener).returns(listener)
    listener.expects(:target)
    Bee::Target.any_instance.expects(:run_block).with([], false)
    object = { 'target' => 'test', 'depends' => ['foo', 'bar'] }
    target = Bee::Target.new(object, targets)
    target.run()
  end

  def test_run_task
    # nominal case with a shell script
    build = mock('listener')
    targets = mock('targets')
    targets.expects(:build).returns(build)
    build.expects(:listener).returns(nil)
    Bee::Target.any_instance.expects(:run_shell).with('test', false)
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, targets)
    target.send(:run_task, 'test')
    # nominal case with a ruby script
    build = mock('listener')
    targets = mock('targets')
    targets.expects(:build).returns(build)
    build.expects(:listener).returns(nil)
    Bee::Target.any_instance.expects(:run_ruby).with('test', false)
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, targets)
    target.send(:run_task, {'rb' => 'test'})
    # nominal case with a shell script
    build = mock('listener')
    targets = mock('targets')
    targets.expects(:build).returns(build)
    build.expects(:listener).returns(nil)
    Bee::Target.any_instance.expects(:run_shell).with('test', false)
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, targets)
    target.send(:run_task, {'sh' => 'test'})
    # nominal case with a super call
    build = mock('listener')
    targets = mock('targets')
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, targets)
    targets.expects(:build).returns(build)
    build.expects(:listener).returns(nil)
    targets.expects(:call_super).with(target, false)
    target.send(:run_task, {'super' => nil})
    # error case when task is not a string nor a hash
    build = mock
    targets = mock
    targets.expects(:build).returns(build)
    build.expects(:listener).returns(nil)
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, targets)
    assert_raise(RuntimeError) { target.send(:run_task, :foo) }
  end

  def test_run_shell
    # nominal case
    context = mock
    build = mock
    targets = mock
    targets.expects(:build).returns(build)
    build.expects(:context).returns(context)
    context.expects(:evaluate_object).returns('')
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, targets)
    target.send(:run_shell, 'test')
    # error case for broken script
    context = mock
    build = mock
    targets = mock
    targets.expects(:build).returns(build)
    build.expects(:context).returns(context)
    context.expects(:evaluate_object).returns('command_that_doesnt_exist')
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, targets)
    assert_raise(Bee::Util::BuildError) { target.send(:run_shell, 'test') }
  end

  def test_run_ruby
    # nominal case
    context = mock
    build = mock
    targets = mock
    targets.expects(:build).returns(build)
    build.expects(:context).returns(context)
    context.expects(:evaluate_script).with('test')
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, targets)
    target.send(:run_ruby, 'test')
    # error case with an interrupt
    context = mock
    build = mock
    targets = mock
    targets.expects(:build).returns(build)
    build.expects(:context).returns(context)
    context.expects(:evaluate_script).raises(Interrupt)
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, targets)
    assert_raise(Interrupt) { target.send(:run_ruby, 'test') }
    # error case with an exception
    context = mock
    build = mock
    targets = mock
    targets.expects(:build).returns(build)
    build.expects(:context).returns(context)
    context.expects(:evaluate_script).raises(Exception.new('TEST'))
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, targets)
    assert_raise(Bee::Util::BuildError) { target.send(:run_ruby, 'test') }
  end

  def test_run_bee_task
    # nominal case
    package_manager = mock
    build = mock
    targets = mock
    targets.expects(:build).returns(build)
    build.expects(:package_manager).returns(package_manager)
    package_manager.expects(:run_task).with('test')
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, targets)
    target.send(:run_bee_task, 'test')
  end

  def test_run_construct
    # nominal case for implemented constructs
    for construct in ['if', 'while', 'for', 'try']
      hash = {construct.to_s => 'test'}
      Bee::Target.any_instance.expects("construct_#{construct}".to_sym).with(hash, false)
      object = { 'target' => 'test' }
      target = Bee::Target.new(object, nil)
      target.send(:run_construct, hash)
    end
    # error case for unknown construct
    hash = {'foo' => 'test'}
    object = { 'target' => 'test' }
    target = Bee::Target.new(object, nil)
    assert_raise(Bee::Util::BuildError) { target.send(:run_construct, hash) }
  end

  def test_construct_if
    # nominal case if true
    target = Bee::Target.new({ 'target' => 'test' }, nil)
    construct = {
      'if'   => 'condition',
      'then' => ['if_true'],
      'else' => ['if_false'],
    }
    target.expects(:evaluate).with('condition').returns(true)
    target.expects(:run_block).with(['if_true'], false)
    target.send(:construct_if, construct, false)
    # nominal case if true with a symbol
    target = Bee::Target.new({ 'target' => 'test' }, nil)
    construct = {
      'if'   => :condition,
      'then' => ['if_true'],
      'else' => ['if_false'],
    }
    target.expects(:evaluate).with(:condition).returns(true)
    target.expects(:run_block).with(['if_true'], false)
    target.send(:construct_if, construct, false)
    # nominal case if false
    target = Bee::Target.new({ 'target' => 'test' }, nil)
    construct = {
      'if'   => 'condition',
      'then' => ['if_true'],
      'else' => ['if_false'],
    }
    target.expects(:evaluate).with('condition').returns(false)
    target.expects(:run_block).with(['if_false'], false)
    target.send(:construct_if, construct, false)
    # error case without then
    target = Bee::Target.new({ 'target' => 'test' }, nil)
    construct = {
      'if'   => 'condition',
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_if, construct, false) }
    # error case with unknown entry
    target = Bee::Target.new({ 'target' => 'test' }, nil)
    construct = {
      'if'   => 'condition',
      'then' => ['if_true'],
      'foo'  => ['if_false'],
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_if, construct, false) }
    # error case with an if that is not a string or a symbol
    target = Bee::Target.new({ 'target' => 'test' }, nil)
    construct = {
      'if'   => Object.new(),
      'then' => ['if_true'],
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_if, construct, false) }
    # error case with a then that is not a list
    target = Bee::Target.new({ 'target' => 'test' }, nil)
    construct = {
      'if'   => 'condition',
      'then' => 'if_true',
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_if, construct, false) }
    # error case with an else that is not a list
    target = Bee::Target.new({ 'target' => 'test' }, nil)
    construct = {
      'if'   => 'condition',
      'then' => ['if_true'],
      'else' => 'if_false',
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_if, construct, false) }
  end

  def test_construct_while
    # nominal case
    target = Bee::Target.new({'target' => 'test'}, nil)
    construct = {
      'while' => 'condition',
      'do'    => ['instruction'],
    }
    seq = sequence('sequence')
    target.expects(:evaluate).with('condition').returns(true).in_sequence(seq)
    target.expects(:run_block).with(['instruction'], false).in_sequence(seq)
    target.expects(:evaluate).with('condition').returns(true).in_sequence(seq)
    target.expects(:run_block).with(['instruction'], false).in_sequence(seq)
    target.expects(:evaluate).with('condition').returns(false).in_sequence(seq)
    target.send(:construct_while, construct, false)
    # error case without do entry
    target = Bee::Target.new({'target' => 'test'}, nil)
    construct = {
      'while' => 'condition',
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_while, construct, false) }
    # error case with unknown entry
    target = Bee::Target.new({'target' => 'test'}, nil)
    construct = {
      'while' => 'condition',
      'do'    => ['instruction'],
      'foo'   => 'bar',
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_while, construct, false) }
    # error case while not a string
    target = Bee::Target.new({'target' => 'test'}, nil)
    construct = {
      'while' => :condition,
      'do'    => ['instruction'],
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_while, construct, false) }
    # error case do not a list
    target = Bee::Target.new({'target' => 'test'}, nil)
    construct = {
      'while' => 'condition',
      'do'    => 'instruction',
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_while, construct, false) }
  end

  def test_construct_for
    # nominal case for a list
    targets = mock
    build = mock
    context = mock
    target = Bee::Target.new({'target' => 'test'}, targets)
    construct = {
      'for' => 'property',
      'in'  => ['value1', 'value2'],
      'do'  => ['instruction'],
    }
    seq = sequence('sequence')
    for value in ['value1', 'value2']
      targets.expects(:build).returns(build).in_sequence(seq)
      build.expects(:context).returns(context).in_sequence(seq)
      context.expects(:set_property).with('property', value).in_sequence(seq)
      target.expects(:run_block).with(['instruction'], false).in_sequence(seq)
    end
    target.send(:construct_for, construct, false)
    # nominal case for an expression
    targets = mock
    build = mock
    context = mock
    target = Bee::Target.new({'target' => 'test'}, targets)
    construct = {
      'for' => 'property',
      'in'  => 'expression',
      'do'  => ['instruction'],
    }
    seq = sequence('sequence')
    targets.expects(:build).returns(build).in_sequence(seq)
    build.expects(:context).returns(context).in_sequence(seq)
    context.expects(:evaluate_script).with('expression').returns(['value1', 'value2' ]).in_sequence(seq)
    for value in ['value1', 'value2']
      targets.expects(:build).returns(build).in_sequence(seq)
      build.expects(:context).returns(context).in_sequence(seq)
      context.expects(:set_property).with('property', value).in_sequence(seq)
      target.expects(:run_block).with(['instruction'], false).in_sequence(seq)
    end
    target.send(:construct_for, construct, false)
    # error case for missing entries
    construct = {
      'in'  => 'expression',
      'do'  => ['instruction'],
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_for, construct, false) }
    construct = {
      'for' => 'property',
      'do'  => ['instruction'],
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_for, construct, false) }
    construct = {
      'for' => 'property',
      'in'  => 'expression',
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_for, construct, false) }
    # error case for unknown entry
    construct = {
      'for' => 'property',
      'in'  => 'expression',
      'do'  => ['instruction'],
      'foo' => 'bar',
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_for, construct, false) }
    # error case for not a string
    construct = {
      'for' => :property,
      'in'  => 'expression',
      'do'  => ['instruction'],
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_for, construct, false) }
    # error case in not a string, a list or a symbol
    construct = {
      'for' => 'property',
      'in'  => Object.new(),
      'do'  => ['instruction'],
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_for, construct, false) }
    # error case do not a list
    construct = {
      'for' => 'property',
      'in'  => 'expression',
      'do'  => 'instruction',
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_for, construct, false) }
  end

  def test_for_in_do_with_in_not_enumerable
    # error case in not resulting in an enumerable
    targets = mock
    build = mock
    context = mock
    target = Bee::Target.new({'target' => 'test'}, targets)
    targets.expects(:build).returns(build)
    build.expects(:context).returns(context)
    context.expects(:evaluate_script).returns(3)
    construct = {
      'for' => 'property',
      'in'  => '3',
      'do'  => ['instruction'],
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_for, construct, false) }
    # error case in not resulting in an enumerable
    targets = mock
    build = mock
    context = mock
    target = Bee::Target.new({'target' => 'test'}, targets)
    targets.expects(:build).returns(build)
    build.expects(:context).returns(context)
    context.expects(:evaluate_object).returns(3)
    construct = {
      'for' => 'property',
      'in'  => :foo,
      'do'  => ['instruction'],
    }
    assert_raise(Bee::Util::BuildError) { target.send(:construct_for, construct, false) }
  end

  def test_construct_try
    # nominal case without exception
    target = Bee::Target.new({'target' => 'test'}, nil)
    construct = {
      'try'   => ['instruction'],
      'catch' => ['recover'],
    }
    seq = sequence('sequence')
    target.expects(:run_block).with(['instruction'], false).in_sequence(seq)
    target.send(:construct_try, construct, false)
    # nominal case with exception
    targets = mock
    build = mock
    listener = mock
    target = Bee::Target.new({'target' => 'test'}, targets)
    construct = {
      'try'   => ['instruction'],
      'catch' => ['recover'],
    }
    seq = sequence('sequence')
    target.expects(:run_block).with(['instruction'], false).raises(Bee::Util::BuildError).in_sequence(seq)
    targets.expects(:build).returns(build).in_sequence(seq)
    build.expects(:listener).returns(listener).in_sequence(seq)
    targets.expects(:build).returns(build).in_sequence(seq)
    build.expects(:listener).returns(listener).in_sequence(seq)
    listener.expects(:recover).in_sequence(seq)
    target.expects(:run_block).with(['recover'], false).in_sequence(seq)
    target.send(:construct_try, construct, false)
    # error case without try
    construct = {
      'catch' => ['instruction'],
    }
    target = Bee::Target.new({'target' => 'test'}, nil)
    assert_raise(Bee::Util::BuildError) { target.send(:construct_try, construct, false) }
    # error case without catch
    construct = {
      'try'   => ['instruction'],
    }
    target = Bee::Target.new({'target' => 'test'}, nil)
    assert_raise(Bee::Util::BuildError) { target.send(:construct_try, construct, false) }
    # error case unknown entry
    construct = {
      'try'   => ['instruction'],
      'catch' => ['instruction'],
      'foo'   => ['instruction'],
    }
    target = Bee::Target.new({'target' => 'test'}, nil)
    assert_raise(Bee::Util::BuildError) { target.send(:construct_try, construct, false) }
    # error case try not a list
    construct = {
      'try'   => 'instruction',
      'catch' => ['instruction'],
    }
    target = Bee::Target.new({'target' => 'test'}, nil)
    assert_raise(Bee::Util::BuildError) { target.send(:construct_try, construct, false) }
    # error case catch not a list
    construct = {
      'try'   => ['instruction'],
      'catch' => 'instruction',
    }
    target = Bee::Target.new({'target' => 'test'}, nil)
    assert_raise(Bee::Util::BuildError) { target.send(:construct_try, construct, false) }
  end

  def test_if
    # nominal case
    source = '---
- target: test
  script:
    - if: "true"
      then:
        - print: "true"
      else:
        - print: "false"'
    listener = run_build(source, 'test')
    assert("true\n", listener.output)
    assert(listener.started)
    assert(listener.finished)
    assert(!listener.error?)
    # nominal case with boolean
    source = '---
- target: test
  script:
    - if: true
      then:
        - print: "true"
      else:
        - print: "false"'
    listener = run_build(source, 'test')
    assert("true\n", listener.output)
    assert(listener.started)
    assert(listener.finished)
    assert(!listener.error?)
    # test without 'then' entry
    source = '---
- target: test
  script:
    - if: true
      else:
        - print: "false"'
    listener = run_build(source, 'test')
    flunk "Should fail because missing then entry" if listener.successful
    assert_equal("If-then-else construct must include 'then' entry",
                 listener.errors.first.message)
    # test with unknown entry
    source = '---
- target: test
  script:
    - if: true
      then:
        - print: "true"
      also:
        - print: "false"'
    listener = run_build(source, 'test')
    flunk "Should fail because unknown entry" if listener.successful
    assert_equal("If-then-else construct may only include 'if', 'then' and 'else' entries",
                 listener.errors.first.message)
    # test with bad if expression
    source = '---
- target: test
  script:
    - if: "unknown_function()"
      then:
        - print: "true"'
    listener = run_build(source, 'test')
    flunk "Should fail because bad expression" if listener.successful
    assert_match("Error evaluating expression: undefined method `unknown_function'",
                 listener.errors.first.message)
  end

  def test_while
    # nominal case
    source = '---
- properties:
    i: 5

- target: test
  script:
    - while: i > 0
      do:
        - print: :i
        - rb:    i -= 1'
    listener = run_build(source, 'test')
    assert_equal("5\n4\n3\n2\n1\n", listener.output)
    assert(listener.started)
    assert(listener.finished)
    assert(!listener.error?)
    # error without do entry
    source = '---
- target: test
  script:
    - while: i > 0
      then:
      - print: :i'
    listener = run_build(source, 'test')
    flunk "Should fail because missing do entry" if listener.successful
    assert_match("While-do construct must include 'do' entry",
                 listener.errors.first.message)
    # error with unknown key
    source = '---
- target: test
  script:
    - while: i > 0
      do:
        - print: :i
      else:
        - print: strange!'
    listener = run_build(source, 'test')
    flunk "Should fail because missing do entry" if listener.successful
    assert_match("While-do construct may only include 'while' and 'do' entries",
                 listener.errors.first.message)
    # error for bad condition
    source = '---
- target: test
  script:
    - while: "unknown_function()"
      do:
        - print: :i'
    listener = run_build(source, 'test')
    flunk "Should fail because bad expression" if listener.successful
    assert_match("Error evaluating expression: undefined method `unknown_function'",
                 listener.errors.first.message)
  end

  def test_for
    # nominal case
    source = '---
- target: test
  script:
    - for: i
      in:  (1..5)
      do:
        - print: :i'
    listener = run_build(source, 'test')
    assert_equal("1\n2\n3\n4\n5\n", listener.output)
    assert(listener.started)
    assert(listener.finished)
    assert(!listener.error?)
    # error without do entry
    source = '---
- target: test
  script:
    - for: i
      in:  (1..5)'
    listener = run_build(source, 'test')
    flunk "Should fail because missing do entry" if listener.successful
    assert_equal("For-in-do construct must include 'in' and 'do' entries",
                 listener.errors.first.message)
    # error without in entry
    source = '---
- target: test
  script:
    - for: i
      do:
        - print: test'
    listener = run_build(source, 'test')
    flunk "Should fail because missing do entry" if listener.successful
    assert_equal("For-in-do construct must include 'in' and 'do' entries",
                 listener.errors.first.message)
    # error with unknown key
    source = '---
- target: test
  script:
    - for: i
      in:  (1..5)
      do:
        - print: :i
      else:
        - print: strange!'
    listener = run_build(source, 'test')
    flunk "Should fail because unknown entry" if listener.successful
    assert_match("For-in-do construct may only include 'for', 'in' and 'do' entries",
                 listener.errors.first.message)
    # error for bad in expression
    source = '---
- target: test
  script:
    - for: i
      in:  "unknown_function()"
      do:
        - print: :i'
    listener = run_build(source, 'test')
    flunk "Should fail because bad in expression" if listener.successful
    assert_match("Error evaluating expression: undefined method `unknown_function'",
                 listener.errors.first.message)
    # error setting property
    source = '---
- target: test
  script:
    - for: "unknown_function()"
      in:  (1..5)
      do:
        - print: :i'
    listener = run_build(source, 'test')
    flunk "Should fail because bad in expression" if listener.successful
    assert_equal("Error setting property 'unknown_function()'",
                 listener.errors.first.message)
  end

  def test_try
    # nominal case
    source = '---
- target: test
  script:
    - try:
        - print: "OK"
      catch:
        - print: "KO"'
    listener = run_build(source, 'test')
    assert("OK\n", listener.output)
    assert(listener.started)
    assert(listener.finished)
    assert(!listener.error?)
    # nominal case with an exception
    source = '---
- target: test
  script:
    - try:
        - rb: "error \"Exception\""
      catch:
        - print: "KO"'
    listener = run_build(source, 'test')
    assert("KO\n", listener.output)
    assert(listener.started)
    assert(listener.finished)
    assert(!listener.error?)
  end

  private

  def run_build(source, target='')
    build_file = File.join(@tmp_dir, 'build.yml')
    File.open(build_file, 'w') {|file| file.write(source)}
    listener = TestBuildListener.new
    build = Bee::Build::load(build_file)
    begin
      build.run(target, listener)
    rescue
    end
    return listener
  end

end
