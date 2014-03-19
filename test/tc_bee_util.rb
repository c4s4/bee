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
require 'fileutils'
$:.unshift(File.join(File.dirname(__FILE__)))
require 'tmp_test_case'
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'bee_util'
require 'date'

class TestBeeUtil < TmpTestCase

  include Bee::Util::HashCheckerMixin

  def test_term_width
    # TODO: save old method definition
    # test nominal case
    # Doesn't work on Tiger
    #expected = 67
    #IO.send(:define_method, :ioctl) do |tiocgwinsz, string|
    #string[2] = expected
    #  return 1
    #end
    #actual = Bee::Util::term_width
    #assert_equal(expected, actual)
    # test when cols < 0 (send back default term width)
    expected = Bee::Util::DEFAULT_TERM_WIDTH
    IO.send(:define_method, :ioctl) do |tiocgwinsz, string|
      string[3] = 256
      return 1
    end
    actual = Bee::Util::term_width
    assert_equal(expected, actual)
    # test when ioctl return a value < 0
    expected = Bee::Util::DEFAULT_TERM_WIDTH
    IO.send(:define_method, :ioctl) do |tiocgwinsz, string|
      return -1
    end
    actual = Bee::Util::term_width
    assert_equal(expected, actual)
    # test when ioctl raises an error
    expected = Bee::Util::DEFAULT_TERM_WIDTH
    IO.send(:define_method, :ioctl) do |tiocgwinsz, string|
      raise "TEST"
    end
    actual = Bee::Util::term_width
    assert_equal(expected, actual)
  end

  def test_get_package_name
    # nominal case
    packaged = 'foo.bar'
    expected_package = 'foo'
    expected_name = 'bar'
    actual_package, actual_name = Bee::Util::get_package_name(packaged)
    assert_equal(expected_package, actual_package)
    assert_equal(expected_name, actual_name)
    # default package
    packaged = 'bar'
    expected_package = 'default'
    expected_name = 'bar'
    actual_package, actual_name = Bee::Util::get_package_name(packaged)
    assert_equal(expected_package, actual_package)
    assert_equal(expected_name, actual_name)
  end

  def test_get_file
    # nominal case with absolute path and no base
    expected = 'TEST'
    base = @tmp_dir
    name = 'test.txt'
    file = File.join(base, name)
    File.open(file, 'w') {|f| f.write(expected)}
    actual = Bee::Util.get_file(file)
    assert_equal(expected, actual)
    # nominal case with relative file and base
    actual = Bee::Util.get_file(name, base)
    assert_equal(expected, actual)
    # file not found
    filename = '/toto'
    assert_raise(Errno::ENOENT) do
      Bee::Util::get_file(filename)
    end
    # nominal case with URL and no base
    if ENV['NET_TEST'] == 'true'
      url = 'http://www.example.com'
      expected = /<title>IANA &mdash; Example domains<\/title>/
      actual = Bee::Util::get_file(url)
      assert_match(expected, actual)
      # nominal case with URL and a base
      base = 'http://www.example.com'
      url = 'index.html'
      expected = /<title>IANA &mdash; Example domains<\/title>/
      actual = Bee::Util::get_file(url, base)
      assert_match(expected, actual)
      # error case for an unknown host
      url = 'http://xxx.lgseugslgsiuregfg.jyd'
      assert_raise(SocketError) do
        Bee::Util::get_file(url)
      end
      # error case for a 404 error
      url = 'http://www.iana.org/domains/example/foo'
      assert_raise(Net::HTTPServerException) do
        Bee::Util::get_file(url)
      end
    end
  end

  # Test find method.
  def test_find
    # nominal case
    file = File.join(@tmp_dir, 'file.txt')
    File.open(file, 'w') {|file| file.write('TEST')}
    dir = File.join(@tmp_dir, 'dir')
    FileUtils.mkdir(dir)
    Dir.chdir(dir)
    actual = Bee::Util::find('file.txt')
    expected = '../file.txt'
    assert_equal(expected, actual)
    # failure: file not found
    begin
      Bee::Util::find('foo.bar')
      flunk "Should have failed"
    rescue
      expected = 'File not found'
      actual = $!.to_s
      assert_equal(expected, actual)
    end
  end

  def test_url?
    # test URL
    assert(Bee::Util::url?('http://foo/bar'))
    # test not URL
    assert(!Bee::Util::url?('http:foo/bar'))
    assert(!Bee::Util::url?('toto'))
    assert(!Bee::Util::url?('toto://http://'))
    assert(!Bee::Util::url?(3))
  end

  def test_resource?
    # test resource
    assert(Bee::Util::resource?('ruby://foo'))
    assert(Bee::Util::resource?(':foo'))
    # test not resource
    assert(!Bee::Util::resource?('rb://foo'))
    assert(!Bee::Util::resource?('toto'))
    assert(!Bee::Util::resource?('toto://ruby://'))
    assert(!Bee::Util::resource?('toto:'))
    assert(!Bee::Util::resource?(3))
  end

  def test_absolute_path?
    # test relative path
    assert(! Bee::Util::absolute_path?('foo'))
    # test absolute path
    if RUBY_PLATFORM =~ /mswin/
      path = 'c:/foo/bar'
    else
      path = '/foo/bar'
    end
    assert(Bee::Util::absolute_path?(path))
    # test URL
    assert(Bee::Util::absolute_path?('http://foo/bar'))
    # test resource
    assert(Bee::Util::absolute_path?('ruby://toto'))
  end

  def test_absolute_path
    # test relative path
    path = 'foo'
    if RUBY_PLATFORM =~ /mswin/
      base = 'c:/base'
      expected = 'c:/base/foo'
    else
      base = '/base'
      expected = '/base/foo'
    end
    assert_equal(expected, Bee::Util::absolute_path(path, base))
    # test absolute path
    if RUBY_PLATFORM =~ /mswin/
      path = 'c:/foo/bar'
    else
      path = '/foo/bar'
    end
    assert_equal(path, Bee::Util::absolute_path(path, base))
    # test URL
    expected = 'http://foo/bar'
    actual = Bee::Util::absolute_path(expected)
    assert_equal(expected, actual)
    if bee_available?()
      # test resource (bee must have been installed so that 'bee' gem is
      # installed, or test will fail).
      resource = 'ruby://bee/foo'
      expected = /\/foo/
      actual = Bee::Util::absolute_path(resource)
      assert_match(expected, actual)
    end
  end

  def test_fetch
    if ENV['NET_TEST'] == 'true'
      # nominal case
      expected = /<title>IANA &mdash; Example domains<\/title>/
      actual = Bee::Util::fetch('http://www.example.com')
      assert_match(expected, actual)
      # nominal case with redirection
      expected = /<title>Redirect test page<\/title>/
      actual = Bee::Util::fetch('http://jigsaw.w3.org/HTTP/300/307.html')
      assert_match(expected, actual)
      # error cases
      expected = /getaddrinfo:.*/
      begin
        Bee::Util::fetch('http://www.kbhzkbkbv.com/')
        flunk('Should have failed')
      rescue
        assert_match(expected, $!.message)
      end
      begin
        Bee::Util::fetch('http://www.iana.org/domains/example/foo')
        flunk('Should have failed')
      rescue
        assert_equal('404 "NOT FOUND"', $!.message.upcase)
      end
    end
    ## test basic authentication starting a Sinatra server
    #pid = fork do
    #  Kernel.module_eval %q{
    #    def puts(*args)
    #    end
    #  }
    #  TestBasicAuthServer.run!
    #  Kernel.module_eval %q{
    #    def puts(*args)
    #      $stdout.puts(*args)
    #    end
    #  }
    #end
    #sleep(2)
    #expected = "You're welcome!"
    #sleep(1)
    #actual = Bee::Util::fetch('http://localhost:4567/', 10,
    #                          'admin', 'admin')
    #assert_equal(expected, actual)
    #Process.kill(9, pid)
  end

  # Bee must have been installed with gem for this test to succeed.
  def test_resource_path
    if bee_available?()
      # test compact resource without version
      resource = ':bee:path'
      path = Bee::Util::resource_path(resource)
      assert_match(/gems\/bee-.*?\/path$/, path)
      # test compact resource without version
      resource = ':bee:foo/bar'
      path = Bee::Util::resource_path(resource)
      assert_match(/gems\/bee-.*?\/foo\/bar$/, path)
      # test compact resource with version
      resource = ':bee:path[>=0.4.0]'
      path = Bee::Util::resource_path(resource)
      assert_match(/gems\/bee-.*?\/path$/, path)
      # test expanded resource without version
      resource = 'ruby://bee/path'
      path = Bee::Util::resource_path(resource)
      assert_match(/gems\/bee-.*?\/path$/, path)
      # test expanded resource with version
      resource = 'ruby://bee:>=0.4.0/path'
      path = Bee::Util::resource_path(resource)
      assert_match(/gems\/bee-.*?\/path$/, path)
    end
    # test bad resource name
    resource = 'foo'
    begin
      Bee::Util::resource_path(resource)
      flunk('Should have failed')
    rescue
      assert_equal("'foo' is not a valid resource", $!.message)
    end
    # test bad gem
    resource = ':unknown_gem:bar'
    begin
      Bee::Util::resource_path(resource)
      flunk('Should have failed')
    rescue
      assert_equal("Gem 'bee_unknown_gem' was not found", $!.message)
    end
    # test bad version
    resource = ':bee:foo[bar]'
    begin
      Bee::Util::resource_path(resource)
      flunk('Should have failed')
    rescue
      assert($!.message =~ /Illformed requirement \[("?)bar("?)\]/ ||
             $!.message =~ /Gem 'bee' was not found in version 'bar'/)
    end
    if bee_available?()
      # test bad version
      resource = ':bee:foo[1000]'
      begin
        Bee::Util::resource_path(resource)
        flunk('Should have failed')
      rescue
        assert_equal("Gem 'bee' was not found in version '1000'", $!.message)
      end
    end
  end

  def test_find_template
    if bee_available?()
      # nominal case
      expected = /gems\/bee-.*?\/egg\/package.yml$/
      actual = Bee::Util::find_template('package')
      assert_match(expected, actual)
      actual = Bee::Util::find_template('bee.package')
      assert_match(expected, actual)
    end
    # malformed package name
    assert_raise(Bee::Util::BuildError) do
      Bee::Util::find_template('foo.bar.spam')
    end
    assert_raise(Bee::Util::BuildError) do
      Bee::Util::find_template('.foo')
    end
    # package not found
    assert_raise(Bee::Util::BuildError) do
      Bee::Util::find_template('not_found.foo')
    end
    # template not found
    assert_raise(Bee::Util::BuildError) do
      Bee::Util::find_template('bee.foo')
    end
  end

  def test_search_templates
    if bee_available?()
      # a single template
      expected_template = ['bee.package']
      actual = Bee::Util::search_templates('bee.package')
      assert_equal(expected_template, actual.keys())
      # a single template with default package
      expected_template = ['bee.package']
      actual = Bee::Util::search_templates('package')
      assert_equal(expected_template, actual.keys())
      # no template found
      expected = {}
      actual = Bee::Util::search_templates('bee.foo')
      assert_equal(expected, actual)
    end
    # malformed package name
    assert_raise(Bee::Util::BuildError) do
      Bee::Util::search_templates('foo.bar.spam')
    end
    assert_raise(Bee::Util::BuildError) do
      Bee::Util::search_templates('.foo')
    end
    # package not found
    assert_raise(Bee::Util::BuildError) do
      Bee::Util::search_templates('not_found.foo')
    end
    # package not found with joker
    assert_raise(Bee::Util::BuildError) do
      Bee::Util::search_templates('foo.*')
    end
  end

  def test_method_info
    expected = {
      :comment => "Test method foo.\n",
      :defn => "foo",
      :params => [],
      :source => "def foo\nend\n"
    }
    actual = TestMethodInfo.method_info('foo')
    assert_equal(expected[:comment], actual.comment)
    assert_equal(expected[:defn],    actual.defn)
    assert_equal(expected[:params],  actual.params)
    assert_equal(expected[:source],  actual.source)
    expected = {
      :comment => "Test method bar:\n- toto: a parameter.",
      :defn => "bar(toto)",
      :params => ["toto"],
      :source => "def bar(toto)\n  @toto = toto\nend\n"
    }
    actual = TestMethodInfo.method_info(:bar)
    assert_equal(expected[:comment], actual.comment)
    assert_equal(expected[:defn],    actual.defn)
    assert_equal(expected[:params],  actual.params)
    assert_equal(expected[:source],  actual.source)
  end

  def test_check_hash
    description = {
      'mandatory' => :mandatory, 
      'optional'  => :optional
    }
    # nominal cases
    hash = {
      'mandatory' => 'test',
      'optional'  => 'test'
    }
    check_hash(hash, description)
    hash = {
      'mandatory' => 'test'
    }
    check_hash(hash, description)    
    # test missing mandatory
    hash = {
      'unknown'   => 'test'
    }
    begin
      check_hash(hash, description)
      fail('Should have failed due to a missing mandatory key')
    rescue
      assert_equal("Missing mandatory key 'mandatory'", $!.message)
    end
    # test unknown key
    hash = {
      'mandatory' => 'test',
      'unknown'   => 'test'
    }
    begin
      check_hash(hash, description)
      fail('Should have failed due to an unknown key')
    rescue
      assert_equal("Unknown key 'unknown'", $!.message)
    end
    # test unknown symbol
    bad_description = {
      'test' => :test
    }
    hash = {}
    begin
      check_hash(hash, bad_description)
      fail('Should have failed due to an unknown symbol')
    rescue
      assert_equal("Unknown symbol 'test'", $!.message)
    end
  end
  
  def test_gem_available?
    assert_equal(true, Bee::Util::gem_available?('bee')) if bee_available?
    assert_equal(false, Bee::Util::gem_available?('mkbmkrmkiqgqmgmk'))
  end
  
  ##############################################################################
  #                       UTILITY METHODS (NOT TESTS)                          #
  ##############################################################################

  private

  # Test class for method info
  class TestMethodInfo < Bee::Util::MethodInfoBase

=begin
Test method foo.
=end
    def foo
    end

    # Test method bar:
    # - toto: a parameter.
    def bar(toto)
      @toto = toto
    end

  end

  require 'rubygems'
  require 'sinatra/base'

  class TestBasicAuthServer < Sinatra::Base

    use Rack::Auth::Basic, "Restricted Area" do |username, password|
      [username, password] == ['admin', 'admin']
    end

    get '/' do
      "You're welcome!"
    end

  end
  
end

