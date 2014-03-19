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
require 'bee_task_packagemanager'

class TestBeeTaskPackageManager < TmpTestCase
  
  def test_run_task
    # nominal case with two calls (to check that packages are cached)
    task = {'foo.bar' => 'param'}
    build = mock
    context = mock
    package = mock
    package_manager = Bee::Task::PackageManager.new(build)
    seq = sequence('sequence')
    build.expects(:context).returns(context).in_sequence(seq)
    context.expects(:evaluate_object).with('param').returns('param').in_sequence(seq)
    Bee::Task::PackageManager.expects(:load_package).returns(package).in_sequence(seq)
    package.expects(:respond_to?).with('bar').returns(true).in_sequence(seq)
    package.expects(:bar).with('param').in_sequence(seq)
    # second run: doesn't load package anymore
    build.expects(:context).returns(context).in_sequence(seq)
    context.expects(:evaluate_object).with('param').returns('param').in_sequence(seq)
    package.expects(:respond_to?).with('bar').returns(true).in_sequence(seq)
    package.expects(:bar).with('param').in_sequence(seq)
    package_manager.run_task(task)
    package_manager.run_task(task)
    # error case with a task that doesn't exist
    task = {'foo.bar' => 'param'}
    build = mock
    context = mock
    package = mock
    package_manager = Bee::Task::PackageManager.new(build)
    seq = sequence('sequence')
    build.expects(:context).returns(context).in_sequence(seq)
    context.expects(:evaluate_object).with('param').returns('param').in_sequence(seq)
    Bee::Task::PackageManager.expects(:load_package).returns(package).in_sequence(seq)
    package.expects(:respond_to?).with('bar').returns(false).in_sequence(seq)
    assert_raise(Bee::Util::BuildError) { package_manager.run_task(task) }
  end

  def test_help_task
    # nominal case for a single task
    build = stub
    context = stub
    package = stub
    clazz = stub
    info = stub
    package_manager = Bee::Task::PackageManager.new(build)
    build.stubs(:context).returns(context)
    context.stubs(:evaluate_object).with('param').returns('param')
    Bee::Task::PackageManager.stubs(:load_package).returns(package)
    package.stubs(:respond_to?).with('bar').returns(true)
    package.stubs(:class).returns(clazz)
    clazz.stubs(:method_info).with('bar').returns(info)
    info.stubs(:comment).returns('Help about foo.bar')
    expected = { 'foo.bar' => 'Help about foo.bar' }
    actual = package_manager.help_task('foo.bar')
    assert_equal(expected, actual)
  end

  def test_help_task_all
    # nominal case for all tasks
    build = stub
    context = stub
    package = stub
    clazz = stub
    info_spam = stub
    info_eggs = stub
    package_manager = Bee::Task::PackageManager.new(build)
    build.stubs(:context).returns(context)
    context.stubs(:evaluate_object).with('param').returns('param')
    Bee::Task::PackageManager.stubs(:load_package).returns(package)
    package.stubs(:respond_to?).with('bar').returns(true)
    package.stubs(:class).returns(clazz)
    clazz.stubs(:method_info).with('spam').returns(info_spam)
    clazz.stubs(:method_info).with('eggs').returns(info_eggs)
    clazz.stubs(:public_instance_methods).returns(['spam', 'eggs'])
    info_spam.stubs(:comment).returns('Help about foo.spam')
    info_eggs.stubs(:comment).returns('Help about foo.eggs')
    expected = {
      'spam' => 'Help about foo.spam',
      'eggs' => 'Help about foo.eggs',
    }
    actual = package_manager.help_task('foo.?')
    assert_equal(expected, actual)
  end

  def test_help_task_error
    # error case for unknown task
    build = stub
    context = stub
    package = stub
    package_manager = Bee::Task::PackageManager.new(build)
    build.stubs(:context).returns(context)
    context.stubs(:evaluate_object).with('param').returns('param')
    package_manager.stubs(:load_package).with('foo').returns(package)
    package.stubs(:respond_to?).with('bar').returns(false)
    assert_raise(Bee::Util::BuildError) { package_manager.help_task('foo.bar') }
  end

  def test_load_package
    if bee_available?
      package = Bee::Task::PackageManager.send(:load_package, nil)
      assert_equal(Bee::Task::Default, package.class)
    end
    assert_raise(Bee::Util::BuildError) { Bee::Task::PackageManager.send(:load_package, 'foo') }
  end

  def test_list_tasks
    if bee_available?
      expected = ["bee", "cat", "cd", "chmod", "chown", "copy", "cp", "echo",
        "erb", "find", "for", "ftp_get", "ftp_login", "ftp_mkdir", "ftp_put",
        "gem", "gunzip", "gzip", "http_get", "if", "link", "ln", "mail", "mkdir",
        "move", "mv", "print", "prompt", "pwd", "raise", "rdoc", "required",
        "rm", "rmdir", "rmrf", "sleep", "tar", "targz", "test", "throw",
        "touch", "try", "untar", "unzip", "wait", "while", "yaml_dump",
        "yaml_load", "zip"]
      actual = Bee::Task::PackageManager.list_tasks()
      assert((expected & actual).length >= expected.length)
    end
  end

  def test_list_templates
    if bee_available?
      expected = ["script", "application", "package", "sinatra", "xmlrpc", "source"]
      actual = Bee::Task::PackageManager.list_templates()
      assert((expected & actual).length >= expected.length)
    end
  end

end
