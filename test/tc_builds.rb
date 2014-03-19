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
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'bee_console'
$:.unshift(File.expand_path(File.dirname(__FILE__)))
require 'tmp_test_case'

class TestBeeConsole < TmpTestCase

  def test_nominal
    assert_build(/Hello World!/) do
'
- build: test
  default: test

- target: test
  script:
  - print: "Hello World!"
'
    end
  end

  def test_recursive
    assert_build(/Hello World!/, ['-r']) do
'
- build: test
  default: test

- target: test
  script:
  - print: "Hello World!"
'
    end
  end

  def test_error_recursive
    assert_output(/ERROR.*?: Build file 'unknown-build-file.yml' not found recursively/) do
      arguments = ['-r', '-f', 'unknown-build-file.yml']
      assert_raise(SystemExit) { Bee::Console.start_command_line(arguments) }
    end
  end

  def test_error_build_info
    assert_build(/ERROR.*?: Error parsing build info entry: Unknown key 'foo'/, [], SystemExit) do
'
- build: test
  foo:   bar
'
    end
  end

  def test_error_parent
    assert_build(/ERROR.*?: Error loading parent build file/, [], SystemExit) do
'
- build:   test
  extends: bar.yml
'
    end
  end

  def test_error_property_collision
    parent = '- properties:
    foo: 1'
    write_tmp_file('parent1.yml', parent)
    write_tmp_file('parent2.yml', parent)
    assert_build(/ERROR.*?: Properties in parents are colliding: foo/, [], SystemExit) do
'
- build:   test
  extends: [parent1.yml, parent2.yml]
'
    end
  end

  def test_error_target_collision
    parent = '- target: foo'
    write_tmp_file('parent1.yml', parent)
    write_tmp_file('parent2.yml', parent)
    assert_build(/ERROR.*?: Targets in parents are colliding: foo/, [], SystemExit) do
'
- build:   test
  extends: [parent1.yml, parent2.yml]
'
    end
  end

  def test_property
    assert_build(/Hello World!/, ['-p', 'who=World']) do
'
- build: test
  default: test

- target: test
  script:
  - print: "Hello #{who}!"
'
    end
  end

  def test_error_property
    assert_build(/ERROR: parsing command line: Error parsing property 'who': No = sign \(should be 'name=value'\)/,
      ['-p', 'who'], SystemExit) do
'
- build: test
  default: test

- target: test
  script:
  - print: "Hello #{who}!"
'
    end
  end

  def test_error_command_line
    assert_build(/ERROR: parsing command line: invalid option -- z/, ['-z'], SystemExit)
  end

  def test_bee_help
    assert_build(/Usage: bee \[options\] \[targets\]/, ['-h'])
  end

  def test_build_help
    assert_build(/properties:\n- base: .*?\n- here: .*?targets:\n- test/m, ['-b']) do
'
- target: test
  script:
  - print: "Hello World!"
'
    end
  end

  def test_task_help
    if bee_available?
      assert_build(/Alias for echo./, ['-k', 'print'])
    end
  end

  def test_error_task_help
    # error case for task help
    if bee_available?
      assert_build(/ERROR.*?: Task 'foo' not found in package 'default'/,
        ['-k', 'foo'], SystemExit)
    end
  end

  def test_error_template
    if bee_available?
      assert_build(/ERROR.*?: Template 'foo' not found/, ['-t', 'foo'], SystemExit)
    end
  end

  def test_print_targets
    assert_build(/bar foo/, ['-a']) do
'
- target: foo
- target: bar
'
    end
  end

  def test_error_print_targets
    assert_output(/^$/) do
      arguments = ['-f', 'foo.bar', '-a']
      Bee::Console.start_command_line(arguments)
    end
  end
  
  def test_build_interrupt
    assert_build(/ERROR.*?: Build was interrupted!/, [], SystemExit) do
'
- build: test
  default: interrupt

- target: interrupt
  script:
  - rb: "raise Interrupt.new(\'Interruption\')"
'
    end
  end

  def test_default_array
    assert_build(/foo.*bar/m) do
'
- build:   test
  default: [foo, bar]

- target:  foo
  script:
  - print: foo

- target:  bar
  script:
  - print: bar
'
    end
  end

  def test_construct_if_symbol
    assert_build(/Test success/) do
'
- build: test
  default: test

- properties:
    bool: true
- target: test
  script:
  - if: :bool
    then:
    - print: "Test success"
    else:
    - print: "Test failure"
'
    end
  end
  
  def test_construct_if_boolean
    assert_build(/Test success/) do
'
- build: test
  default: test

- target: test
  script:
  - try:
    - if: test
      then:
      - print: "Test success"
      else:
      - print: "Test failure"
    catch:
    - print: "Test failure"
'
    end
  end

  def test_construct_while
    assert_build(/0\n1\n2\n3\n4/) do
'
- build: test
  default: test

- properties:
    index: 0
- target: test
  script:
  - while: index < 5
    do:
    - print: :index
    - rb: "index += 1"
'
    end
  end

  def test_construct_for_in_symbol
    assert_build(/Hi foo!\nHi bar!/) do
'
- build: test
  default: test

- properties:
    list: ["foo", "bar"]
- target: test
  script:
  - for: name
    in:  :list
    do:
    - print: "Hi #{name}!"
'
    end
  end

  def test_construct_try
    assert_build(/Try block\nCatch block/) do
'
- build: test
  default: test

- target: test
  script:
  - try:
    - print: "Try block"
    - throw: "Error!"
    catch:
    - print: "Catch block"
'
    end
  end

end
