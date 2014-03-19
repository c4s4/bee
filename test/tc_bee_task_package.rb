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
require 'test_build'
require 'test_build_listener'
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'bee_task_package'

class TestBeeTaskPackageManager < TmpTestCase

  def setup
    super
    @context = Bee::Context.new()
    @listener = TestBuildListener.new
    @build = TestBuild.new(@context, @listener)
    @package = Bee::Task::Package.new(@build)
    @package_manager = Bee::Task::PackageManager.new(@build)
  end

  def test_constructor
    # nominal case with listener
    build = mock
    listener = mock
    formatter = mock
    seq = sequence('sequence')
    build.expects(:listener).returns(listener).in_sequence(seq)
    build.expects(:listener).returns(listener).in_sequence(seq)
    listener.expects(:formatter).returns(formatter).in_sequence(seq)
    formatter.expects(:verbose).returns(true).in_sequence(seq)
    package = Bee::Task::Package.new(build)
    assert(package.verbose)
    # nominal case without listener
    package = Bee::Task::Package.new(nil)
    assert(!package.verbose)
  end

  def test_check_parameters
    # test float field
    params = { 'field' => 'toto' }
    description = { :field => { :mandatory => true,  :type => :float } }
    begin
      @package.send(:check_parameters, params, description)
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = /[\w_]? 'field' parameter must be a float/
      actual = $!.message
      self.assert_match(expected, actual)
    end
    params = { 'field' => 1.23 }
    description = { :field => { :mandatory => true,  :type => :float } }
    @package.send(:check_parameters, params, description)
    # test number field
    params = { 'field' => 'toto' }
    description = { :field => { :mandatory => true,  :type => :number } }
    begin
      @package.send(:check_parameters, params, description)
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = /[\w_]? 'field' parameter must be a number/
      actual = $!.message
      self.assert_match(expected, actual)
    end
    params = { 'field' => 123 }
    description = { :field => { :mandatory => true,  :type => :number } }
    @package.send(:check_parameters, params, description)
    # test boolean field
    params = { 'field' => 'toto' }
    description = { :field => { :mandatory => true,  :type => :boolean } }
    begin
      @package.send(:check_parameters, params, description)
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = /[\w_]? 'field' parameter must be a boolean/
      actual = $!.message
      self.assert_match(expected, actual)
    end
    params = { 'field' => true }
    description = { :field => { :mandatory => true,  :type => :boolean } }
    @package.send(:check_parameters, params, description)
    # test array field
    params = { 'field' => 'toto' }
    description = { :field => { :mandatory => true,  :type => :array } }
    begin
      @package.send(:check_parameters, params, description)
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = /[\w_]? 'field' parameter must be an array/
      actual = $!.message
      self.assert_match(expected, actual)
    end
    params = { 'field' => ['a', 'b', 'c'] }
    description = { :field => { :mandatory => true,  :type => :array } }
    @package.send(:check_parameters, params, description)
    # test string or integer field
    params = { 'field' => [] }
    description = { :field => { :mandatory => true,
        :type => :string_or_integer } }
    begin
      @package.send(:check_parameters, params, description)
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = /[\w_]? 'field' parameter must be a string or an integer/
      actual = $!.message
      self.assert_match(expected, actual)
    end
    params = { 'field' => 'string' }
    description = { :field => { :mandatory => true,
        :type => :string_or_integer } }
    @package.send(:check_parameters, params, description)
    params = { 'field' => 123 }
    description = { :field => { :mandatory => true,
        :type => :string_or_integer } }
    @package.send(:check_parameters, params, description)
    # test hash field
    params = { 'field' => 'toto' }
    description = { :field => { :mandatory => true, :type => :hash } }
    begin
      @package.send(:check_parameters, params, description)
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = /[\w_]? 'field' parameter must be a hash/
      actual = $!.message
      self.assert_match(expected, actual)
    end
    params = { 'field' => { 'foo' => 'bar' } }
    description = { :field => { :mandatory => true, :type => :hash } }
    @package.send(:check_parameters, params, description)
    # test hash or array field
    params = { 'field' => 'toto' }
    description = { :field => { :mandatory => true, :type => :hash_or_array } }
    begin
      @package.send(:check_parameters, params, description)
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = /[\w_]? 'field' parameter must be a hash or list of hashes/
      actual = $!.message
      self.assert_match(expected, actual)
    end
    params = { 'field' => { 'foo' => 'bar' } }
    description = { :field => { :mandatory => true, :type => :hash_or_array } }
    @package.send(:check_parameters, params, description)
    params = { 'field' => [{ 'foo' => 'bar' }] }
    description = { :field => { :mandatory => true, :type => :hash_or_array } }
    @package.send(:check_parameters, params, description)
    # test unknown field type
    params = { 'field' => 'foo' }
    description = { :field => { :mandatory => true, :type => :foo } }
    begin
      @package.send(:check_parameters, params, description)
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = "Unknown parameter type 'foo'"
      actual = $!.message
      self.assert_equal(expected, actual)
    end
    # test default value
    params = {}
    description = { :foo => { :mandatory => false,
        :type => :string, :default => 'bar' } }
    @package.send(:check_parameters, params, description)
    expected = 'bar'
    actual = params[:foo]
    self.assert_equal(expected, actual)
    # test unknown parameter
    params = { 'foo' => 'toto', 'field' => 'bar' }
    description = { :field => { :mandatory => true, :type => :string } }
    begin
      @package.send(:check_parameters, params, description)
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = "Unknown parameter 'foo'"
      actual = $!.message
      self.assert_equal(expected, actual)
    end
  end

  def test_filter_files
    # test includes parameter
    begin
      @package.send(:filter_files, 'bar', 123, 'foo')
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = "includes must be a glob or a list of globs"
      actual = $!.message
      self.assert_equal(expected, actual)
    end
    # test excludes parameter
    begin
      @package.send(:filter_files, 'bar', 'foo', 123)
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = "excludes must be a glob or a list of globs"
      actual = $!.message
      self.assert_equal(expected, actual)
    end
    # test root parameter
    begin
      @package.send(:filter_files, '/dir_that_doesnt_exist', 'foo', 'bar')
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = "root must be an existing directory"
      actual = $!.message
      self.assert_equal(expected, actual)
    end
    # test includes parameter bis
    begin
      @package.send(:filter_files, nil, ['foo', 123], 'bar')
      self.fail('Should have failed')
    rescue Bee::Util::BuildError
      expected = "includes must be a glob or a list of globs"
      actual = $!.message
      self.assert_equal(expected, actual)
    end
  end

  def test_print
    # without listener
    package = Bee::Task::Package.new(nil)
    Kernel.expects(:print).with('foo')
    package.send(:print, 'foo')
    Kernel.expects(:puts).with('bar')
    package.send(:puts, 'bar')
    # with listener
    formatter = mock
    @listener.expects(:formatter).returns(formatter)
    formatter.expects(:print).with('foo')
    @package.send(:print, 'foo')
    formatter = mock
    @listener.expects(:formatter).returns(formatter)
    formatter.expects(:puts).with('bar')
    @package.send(:puts, 'bar')
  end
    
end
