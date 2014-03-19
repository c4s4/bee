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
$:.unshift(File.join(File.dirname(__FILE__)))
require 'tmp_test_case'
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'bee_build'
require 'bee_target'
require 'bee_console_formatter'

class TestBeeConsoleFormatter < TmpTestCase

  def setup()
    super
    @outputer = TestConsoleOutputer.new()
    style = {:line_length => 66}
    @formatter = Bee::Console::Formatter.new(style, nil, nil, @outputer)
    @verbose_formatter = Bee::Console::Formatter.new(style, nil, true, @outputer)
  end

  def test_print_puts
    expected = 'test'
    @formatter.print(expected)
    actual = @outputer.output
    assert_equal(expected, actual)
    @outputer.clear()
    @formatter.puts('test')
    expected = "test\n"
    actual = @outputer.output
    assert_equal(expected, actual)
  end

  def test_print_build_started
    build = TestConsoleBuild.new('build.yml')
    expected = ''
    @formatter.print_build_started(build, false)
    actual = @outputer.output
    assert_equal(expected, actual)
    @outputer.clear
    expected = "Starting build 'build.yml'...\n"
    @verbose_formatter.print_build_started(build, false)
    actual = @outputer.output
    assert_equal(expected, actual)
    @outputer.clear
    expected = "Starting dry run of 'build.yml'...\n"
    @verbose_formatter.print_build_started(build, true)
    actual = @outputer.output
    assert_equal(expected, actual)
  end

  def test_print_build_finished
    @formatter.print_build_finished(12)
    expected = ""
    actual = @outputer.output
    assert_equal(expected, actual)
    @outputer.clear
    @formatter.print_build_finished(123)
    expected = "Built in 123 s\n"
    actual = @outputer.output
    assert_equal(expected, actual)
    @outputer.clear
    @verbose_formatter.print_build_finished(12)
    expected = "Built in 12 s\n"
    actual = @outputer.output
    assert_equal(expected, actual)
    @outputer.clear
    @verbose_formatter.print_build_finished(123)
    expected = "Built in 123 s\n"
    actual = @outputer.output
    assert_equal(expected, actual)
  end

  def test_print_target
    target = TestConsoleTarget.new('test')
    @formatter.print_target(target)
    expected = "#{'-'*58} test --\n"
    actual = @outputer.output
    assert_equal(expected, actual)
    @outputer.clear
    target = TestConsoleTarget.new('test')
    @verbose_formatter.print_target(target)
    expected = "#{'-'*58} test --\n"
    actual = @outputer.output
    assert_equal(expected, actual)
  end

  def test_print_task
    task = "This\n  is a\n  test\n\n"
    @formatter.print_task(task)
    expected = ""
    actual = @outputer.output
    assert_equal(expected, actual)
    @outputer.clear
    @verbose_formatter.print_task(task)
    expected = "- This\n.   is a\n.   test\n"
    actual = @outputer.output
    assert_equal(expected, actual)
  end

  def test_format_target
    target = TestConsoleTarget.new('test')
    expected = "#{'-'*58} test --"
    actual = @formatter.format_target(target)
    assert_equal(expected, actual)
    expected = "#{'-'*58} test --"
    actual = @verbose_formatter.format_target(target)
    assert_equal(expected, actual)
  end

  def test_format_task
    task = "This\n  is a\n  test\n\n"
    expected = "- This\n.   is a\n.   test"
    actual = @formatter.format_task(task)
    assert_equal(expected, actual)
    actual = @verbose_formatter.format_task(task)
    assert_equal(expected, actual)
    task = {'foo' => 'bar'}
    expected = "- foo: bar"
    actual = @formatter.format_task(task)
    assert_equal(expected, actual)
    task = {'rb' => 'puts "TEST"'}
    expected = '- rb: puts "TEST"'
    actual = @formatter.format_task(task)
    assert_equal(expected, actual)
    # if construct
    task = { 'if' => true, 'then' => [{'print' => 'true'}], 'else' => [{'print' => 'false'}]}
    expected = "- if: true\n. then: \n. - print: \"true\"\n. else: \n. - print: \"false\""
    actual = @formatter.format_task(task)
    assert_equal(expected, actual)
    # while construct
    task = { 'while' => true, 'do' => [{'print' => 'again'}]}
    expected = "- while: true\n. do: \n. - print: again"
    actual = @formatter.format_task(task)
    assert_equal(expected, actual)
    # for construct
    task = { 'for' => 'i', 'in' => :list, 'do' => [{'print' => 'again'}]}
    expected = "- for: i\n. in: :list\n. do: \n. - print: again"
    actual = @formatter.format_task(task)
    assert_equal(expected, actual)
    # try construct
    task = { 'try' => [{'print' => 'test'}], 'catch' => [{'print' => 'again'}]}
    expected = "- try: \n. - print: test\n. catch: \n. - print: again"
    actual = @formatter.format_task(task)
    assert_equal(expected, actual)
    # unknown construct
    task = { 'foo' => 1, 'bar' => 2}
    expected = "- UNKNOWN CONSTRUCT"
    actual = @formatter.format_task(task)
    assert_equal(expected, actual)
  end

  def test_format_success
    expected = 'TEST'
    actual = @formatter.format_success(expected)
    assert_equal(expected, actual)
  end

  def test_format_error
    expected = 'TEST'
    actual = @formatter.format_success(expected)
    assert_equal(expected, actual)
  end

  def test_format_error_message
    # with target and task
    exception = Bee::Util::BuildError.new('exception')
    exception.target = TestConsoleTarget.new('last_target')
    exception.task = 'last_task'
    expected = "ERROR: exception\nIn target 'last_target', in task:\n- last_task"
    actual = @formatter.format_error_message(exception)
    assert_equal(expected, actual)
    # with target only
    exception = Bee::Util::BuildError.new('exception')
    exception.target = TestConsoleTarget.new('last_target')
    expected = "ERROR: exception\nIn target 'last_target'"
    actual = @formatter.format_error_message(exception)
    assert_equal(expected, actual)
    # without target or task
    exception = Bee::Util::BuildError.new('exception')
    expected = "ERROR: exception"
    actual = @formatter.format_error_message(exception)
    assert_equal(expected, actual)
  end

  def test_format_description
    title = "Title"
    text = "This is a sample text.\nThis is the second line of text."
    indent = 4
    bullet = true
    expected = "    - Title: \n      This is a sample text.\n      This is the second line of text.\n"
    actual = @formatter.format_description(title, text, indent, bullet)
    assert_equal(expected, actual)
  end

  def test_format_title
    title = 'test'
    expected = "#{'-'*58} test --"
    actual = @formatter.format_title(title)
    assert_equal(expected, actual)
  end

  def test_help_build
    expected = "build: test
extends: parent
description: Test description
properties:
- foo: \"bar\"
- spam: \"eggs\"
- toto: \"titi\"
targets:
- foo
- test: Test description"
    build_yml = "- build: test
  extends: parent.yml
  description: Test description
- properties:
    toto: titi
    foo:  bar
- target: test
  description: Test description"
    parent_yml = "- build: parent
- properties:
    spam: eggs
- target: foo"
    build_file = File.join(@tmp_dir, 'build.yml')
    parent_file = File.join(@tmp_dir, 'parent.yml')
    open(build_file, 'w') {|f| f.write(build_yml)}
    open(parent_file, 'w') {|f| f.write(parent_yml)}
    build = Bee::Build.new(YAML.load(build_yml), build_file)
    formatter = Bee::Console::Formatter.new(nil)
    actual = formatter.help_build(build).gsub(/.*base.*\n?/, '').gsub(/.*here.*\n?/, '')
    assert_equal(expected, actual)
  end

  def test_help_task
    expected = "---------------------------------------------------------- echo --
Print a message on console. If message is not a string, this task
outputs the inspected value of the object.

- message: message to print.

Example

 - echo: \"Hello World!\"
"
    actual = @formatter.help_task('echo')
    assert_equal(expected, actual)
    expected = "--------------------------------------------------------- print --
Alias for echo.

Print a message on console. If message is not a string, this task
outputs the inspected value of the object.

- message: message to print.

Example

 - echo: \"Hello World!\"
"
    actual = @formatter.help_task('print')
    assert_equal(expected, actual)
  end

  def test_help_template
    if bee_available?
      expected = "---------------------------------------------------- bee.source --
This script will generate a sample Ruby source file.
"
      actual = @formatter.help_template("source")
      assert_equal(expected, actual)
    end
  end

end

################################################################################
#                              HELPER CLASS                                    #
################################################################################

class TestConsoleOutputer

  attr_reader :output

  def initialize()
    clear()
  end

  def clear()
    @output = ''
  end

  def print(message)
    @output += message
  end

  def puts(message)
    @output += message
    @output += "\n"
  end

end

class TestConsoleBuild

  attr_reader :file

  def initialize(file)
    @file = file
  end

end

class TestConsoleTarget

  attr_reader :name

  def initialize(name)
    @name = name
  end

end
