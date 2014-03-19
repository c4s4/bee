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
require 'test_build_listener'
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'bee_build'

# Test case for Bee.
class TestBeeBuild < TmpTestCase

  def test_load_error_not_found
    # try loading a build file that doesn't exist
    file = File.join(@tmp_dir, 'foo')
    begin
      Bee::Build::load(file)
      flunk "Build file should not have been found!"
    rescue Bee::Util::BuildError
      expected = "Error loading build file '#{file}': " +
        "No such file or directory - #{file}"
      actual = $!.message
      assert_equal(expected, actual)
    end
  end

  def test_load
    # try loading a build file that is a directory
    begin
      file = @tmp_dir
      Bee::Build::load(file)
      flunk "Build file may not be a directory!"
    rescue Bee::Util::BuildError
      expected = /Error loading build file/
      actual = $!.message
      assert_match(expected, actual)
    end
    # try running a build that should never fail
    build_file = File.join(@tmp_dir, 'build.yml')
    begin
      source = '- target: test
  script:
    - print: "Hello World!"'
      File.open(build_file, 'w') {|file| file.write(source)}
      listener = TestBuildListener.new
      build = Bee::Build::load(build_file)
      build.run('test', listener)
    ensure
      File.delete(build_file)
    end
    # try loading a build file with YAML syntax error
    begin
      source = 
'- target: test
   script: \"test\"'
      File.open(build_file, 'w') {|file| file.write(source)}
      build = Bee::Build::load(build_file)
      flunk "Should fail to parse YAML file!"
    rescue Bee::Util::BuildError
      expected = "Error loading build file '#{build_file}': " +
        "syntax error on line 1, col 10: `   script: \\\"test\\\"'"
      actual = $!.message
      assert_equal(expected, actual)
    ensure
      File.delete(build_file)
    end
    # try loading a build file that is a YAML string
    begin
      source = 'foo'
      File.open(build_file, 'w') {|file| file.write(source)}
      build = Bee::Build::load(build_file)
      flunk "Build object must be a list!"
    rescue Bee::Util::BuildError
      expected = "Build must be a list"
      actual = $!.message
      assert_equal(expected, actual)
    ensure
      File.delete(build_file)
    end
  end
  
  def test_initialize
    # try loading a build object (resulting from loading YAML file) that is not
    # a list
    begin
      Bee::Build.new(Object.new, nil)
      flunk "Build object must be a list!"
    rescue Bee::Util::BuildError
      expected = "Build must be a list"
      actual = $!.message
      assert_equal(expected, actual)
    end
    # try loading a build object with two build info entries
    object = [{'build' => 'test'}, {'build' => 'test'}]
    begin
      Bee::Build.new(object, nil)
      flunk "Build can't have duplicate info entries!"
    rescue Bee::Util::BuildError
      expected = "Duplicate build info"
      actual = $!.message
      assert_equal(expected, actual)
    end
    # try loading a build object defining a context
    context_file = 'context.rb'
    context_path = File.join(@tmp_dir, context_file)
    context_source = 'def test
set_property(:tested, true)
end'
    File.open(context_path, 'w') {|file| file.write(context_source)}
    object = [{'build' => 'test', 'context' => context_file},
      {'target' => 'test', 'script' => [{'rb' => 'test'}]}]
    listener = TestBuildListener.new
    build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
    build.run('test', listener)
    assert(build.context.get_property(:tested))
    assert(listener.started)
    assert(listener.finished)
    assert(!listener.error?)
    # try loading a buggy context
    context_file = 'context.rb'
    context_path = File.join(@tmp_dir, context_file)
    context_source = 'def test end'
    File.open(context_path, 'w') {|file| file.write(context_source)}
    object = [{'build' => 'test', 'context' => context_file},
      {'target' => 'test', 'script' => [{'rb' => 'test'}]}]
    listener = TestBuildListener.new
    begin
      build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
      build.context.evaluate
      flunk "Should have raised a BuildError"
    rescue Bee::Util::BuildError
      assert_match(/Error loading context 'context.rb': /, $!.message)
    end
    # load a build defining properties
    object = [{'properties' => {'foo' => 'bar'}}]
    build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
    build.context.evaluate
    assert_equal(build.context.get_property(:foo), 'bar')
    # load a build defining duplicate properties
    object = [{'properties' => {'foo' => 'bar'}}, {'properties' => {'foo' => 'bar'}}]
    begin
      build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
      flunk
    rescue Bee::Util::BuildError
      assert_equal("Duplicate property definition: 'foo'", $!.message)
    end
    # load a build with unknown entry
    object = [{'foo' => 'bar'}]
    begin
      build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
      flunk
    rescue Bee::Util::BuildError
      assert_match("Unknown entry:", $!.message)
    end
    # try running a buggy build with a listener
    object = [{'target' => 'test', 'script' => [{'foo' => 'bar'}]}]
    listener = TestBuildListener.new
    build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
    assert_raise(Bee::Util::BuildError) { build.run('', listener) }
    assert(listener.started)
    assert(listener.finished)
    assert(listener.errors)
    # try running a buggy build without a listener
    object = [{'target' => 'test', 'script' => [{'foo' => 'bar'}]}]
    build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
    begin
      build.run('test', nil)
      flunk
    rescue Bee::Util::BuildError
      assert_equal("Task 'foo' not found in package 'default'", $!.message)
    end
    # try running a build with dependencies
    target1 = {'target' => 'test1', 
      'script' => [{'rb' => 'set_property(:foo, "bar")'}]}
    target2 = {'target' => 'test2', 'depends' => 'test1'}
    object = [target2, target1]
    listener = TestBuildListener.new
    build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
    build.run('test2', listener)
    assert(listener.started)
    assert(listener.finished)
    assert(!listener.error?)
    assert_equal(['test1', 'test2'], 
                 listener.targets.collect {|target| target.name})
    # run a task with two keys
    object = [{'target' => 'test', 
                'script' => [{'foo' => 'bar', 'spam' => 'eggs'}]}]
    build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
    begin
      build.run('test', nil)
      flunk
    rescue Bee::Util::BuildError
      assert_match(/Unknown construct '(foo|spam)-(spam|foo)'/, $!.message)
    end
    # run a buggy Ruby script
    object = [{'target' => 'test', 'script' => [{'rb' => 'bar'}]}]
    build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
    begin
      build.run('test', nil)
      flunk
    rescue Bee::Util::BuildError
      assert_match(/Error running Ruby script/, $!.message)
    end
    # run a buggy Ruby script (with bad property reference)
    object = [{'target' => 'test', 'script' => [{'print' => :bar}]}]
    build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
    begin
      build.run('test', nil)
      flunk
    rescue Bee::Util::BuildError
      assert_match(/Property 'bar' was not set/,
        $!.message)
    end
    # nominal case for properties file loading
    path = File.join(@tmp_dir, 'properties.yml')
    properties = 'foo: 1
bar: "test"'
    File.open(path, 'w') { |file| file.write(properties) }
    object = [{'properties' => 'properties.yml'}]
    build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
    build.context.evaluate
    expected = ['bar', 'foo']
    actual = build.context.properties.sort.select do |prop|
      not (prop =~ /^base$/ or prop =~ /^here$/)
    end
    assert_equal(expected, actual)
    assert_equal(1, build.context.get_property('foo'))
    assert_equal('test', build.context.get_property('bar'))
    # error case loading buggy build file
    path = File.join(@tmp_dir, 'properties.yml')
    properties = 'foo'
    File.open(path, 'w') { |file| file.write(properties) }
    object = [{'properties' => 'properties.yml'}]
    begin
      build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
      flunk
    rescue Bee::Util::BuildError
      expected = "Error loading properties file 'properties.yml': " +
        "Properties must be a hash"
      assert_equal(expected, $!.message)
    end
    # error case loading build file that doesn't exist
    path = 'foo'
    object = [{'properties' => path}]
    begin
      build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
      flunk
    rescue Bee::Util::BuildError
      expected = "Error loading properties file 'foo': " +
        "No such file or directory - #{File.join(@tmp_dir, path)}"
      assert_equal(expected, $!.message)
    end
    # try loading a build object with default entry that is not a string
    object = [{'build' => 'test', 'default' => :foo}]
    begin
      Bee::Build.new(object, nil)
      flunk "Build default entry must be a string or an array"
    rescue Bee::Util::BuildError
      expected = "'default' entry of the 'build' block must be a string or an array"
      actual = $!.message
      assert_equal(expected, actual)
    end
    # try loading a build object without default target
    object = [{'target' => 'test'}]
    build = Bee::Build.new(object, File.join(@tmp_dir, 'build.yml'))
    begin
      build.run(nil)
      flunk "No default target"
    rescue Bee::Util::BuildError
      expected = "No default target given"
      actual = $!.message
      assert_equal(expected, actual)
    end
  end

  def test_get_base
    # nominal case with URL
    file = 'http://foo.com/bar'
    build = Bee::Build.new([], file)
    assert_equal('http://foo.com', build.send(:get_base, file))
    # nominal case with file
    if windows?
      file = 'c:/foo/bar/build.yml'
      build = Bee::Build.new([], file)
      assert_equal('c:/foo/bar', build.send(:get_base, file))
    else
      file = '/foo/bar/toto'
      build = Bee::Build.new([], file)
      assert_equal('/foo/bar', build.send(:get_base, file))
    end
  end

  def test_get_version
    Bee.expects(:require).with('bee_version').raises(Exception.new('TEST'))
    assert_equal('UNKNOWN', Bee.version())
  end

end
