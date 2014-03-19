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
require 'bee_build'
require 'bee_task_default'
require 'bee_version_dependant'
require 'fileutils'

# Test default bee tasks.
class TestBeeDefaultTasks < TmpTestCase
  
  # Run before any test: create a context object and load tasks in it.
  def setup
    super
    @context = Bee::Context.new()
    @listener = TestBuildListener.new
    @build = TestBuild.new(@context, @listener)
    @package = Bee::Task::Default.new(@build)
  end

  ######################################################################
  #                        MISCELLANEOUS TASKS                         #
  ######################################################################
    
  def test_task_echo
    @package.echo('TEST')
    assert_equal("TEST\n", @listener.output)
    @listener.reset
    @package.echo(['foo', 'bar'])
    assert_equal("[\"foo\", \"bar\"]\n", @listener.output)
  end
  
  def test_task_sleep
    # nominal case
    now = Time.now
    @package.sleep(1)
    duration = (Time.now - now).to_f
    assert((duration > 0.9) && (duration < 1.1))
    # argument error
    begin
      @package.sleep('test')
      flunk 'Should have failed because sleep argument must be an int or float'
    rescue
      assert_equal('sleep parameter must be a float or a integer', $!.message)
    end
  end

  def test_task_prompt
    # nominal cases
    params = { 'message' => 'This is a test', 'property' => 'test_property' }
    @listener.reset
    HighLine.any_instance.expects(:ask).returns('test prompt')
    @package.prompt(params)
    assert_equal('test prompt', @build.context.get_property('test_property'))
    # nominal case with echo char
    params = {
      'message'  => 'This is a test',
      'property' => 'test_property',
      'echo'     => '#',
    }
    @listener.reset
    HighLine.any_instance.expects(:ask).returns('test prompt')
    @package.prompt(params)
    assert_equal('test prompt', @build.context.get_property('test_property'))
    params = {
      'message'  => 'This is a test',
      'property' => 'test_property',
      'default'  => 'default value'
    }
    @listener.reset
    HighLine.any_instance.expects(:ask).returns('')
    @package.prompt(params)
    assert_equal('default value', @build.context.get_property('test_property'))
    params = {
      'message'  => 'This is a test',
      'property' => 'test_property',
      'pattern'  => 'test'
    }
    @listener.reset
    HighLine.any_instance.expects(:ask).returns('test value')
    @package.prompt(params)
    assert_equal('test value', @build.context.get_property('test_property'))
    # error cases for missing parameters
    params = { 'message' => 'This is a test' }
    @listener.reset
    HighLine.any_instance.expects(:ask).returns('')
    begin
      @package.prompt(params)
      flunk 'Should have failed for missing property parameter'
    rescue
      assert_equal("prompt 'property' parameter is mandatory", $!.message)
    end
    params = { 'property' => 'test_property' }
    @listener.reset
    begin
      @package.prompt(params)
      flunk 'Should have failed for missing message parameter'
    rescue
      assert_equal("prompt 'message' parameter is mandatory", $!.message)
    end
    # error case pattern not matched
    params = {
      'property' => 'test_property',
      'message'  => 'test message',
      'pattern'  => 'foo',
      'attempts' => 1
    }
    @listener.reset
    @listener.prompt = 'test'
    begin
      @package.prompt(params)
      flunk 'Should have failed for unmatched prompt'
    rescue
      assert_equal("Failed to obtain a matching prompt", $!.message)
    end    
  end

  def test_task_throw
    # nominal case
    assert_raise(Bee::Util::BuildError) { @package.throw('TEST') }
    assert_raise(Bee::Util::BuildError) { @package.throw(:TEST) }
  end

  def test_task_http_get
    # test nominal case if network tests enabled
    if ENV['NET_TEST'] == 'true'
      expected = /<title>IANA &mdash; Example domains<\/title>/
      dest = File.join(@tmp_dir, 'test.html')
      params = { 'url' => 'http://www.example.com', 'dest' => dest }
      @package.http_get(params)
      actual = File.read(dest)
      assert_match(expected, actual)
      # with dest directory
      dest = File.join(@tmp_dir, 'index.html')
      params = {
        'url' => 'http://www.example.com/index.html',
        'dest' => @tmp_dir
      }
      @package.http_get(params)
      actual = File.read(dest)
      assert_match(expected, actual)
      # with dest property
      params = { 'url' => 'http://www.example.com', 'prop' => 'property' }
      @package.http_get(params)
      actual = @build.context.get_property('property')
      assert_match(expected, actual)
      # error case: can't save file
      dest = File.join(@tmp_dir, 'test.html')
      FileUtils.touch(dest)
      FileUtils.chmod(0000, dest)
      params = { 'url' => 'http://www.example.com', 'dest' => dest }
      @listener.reset
      begin
        @package.http_get(params)
        flunk 'Should fail because file could not be saved'
      rescue
        assert($!.message =~ /Error saving file: Permission denied/)
      ensure
        FileUtils.chmod(0644, dest)
      end
    end
    # error case: missing url
    params = {}
    @listener.reset
    begin
      @package.http_get(params)
      flunk 'Should fail because url parameter is missing'
    rescue
      assert_equal("http_get 'url' parameter is mandatory", $!.message)
    end
    # error case: url not found
    params = { 'url' => 'http://kbslubvkb/' }
    @listener.reset
    begin
      @package.http_get(params)
      flunk 'Should fail because url is not found'
    rescue
      assert_match(/^Error getting URL: getaddrinfo:/, $!.message)
    end
  end

  def test_mail
    # nominal case
    params = {
      'from'     => 'from@example.net',
      'to'       => 'to@example.net',
      'subject'  => 'subject',
      'message'  => 'message',
      'smtp'     => 'smtp.example.net',
      'encoding' => 'utf-8',
    }
    body = <<EOF
MIME-Version: 1.0
Content-Type: text/plain; charset=#{params['encoding']}
From: #{params['from']}
To: #{params['to']}
Subject: #{params['subject']}

#{params['message']}
EOF
    smtp_server = mock
    Net::SMTP.expects(:start).with(params['smtp']).yields(smtp_server)
    smtp_server.expects(:send_message).with(body, params['from'], [params['to']])
    @package.mail(params)
    # error case
    Net::SMTP.expects(:start).with(params['smtp']).raises(Exception.new('TEST'))
    assert_raise(Bee::Util::BuildError) { @package.mail(params) }
  end
  
  ######################################################################
  #                         FILE RELATED TASKS                         #
  ######################################################################
    
  def test_task_cat
    path = File.join(@tmp_dir, 'test.txt')
    File.open(path, 'w') {|file| file.write('TEST')}
    @package.cat(path)
    assert_equal("TEST\n", @listener.output)
    @listener.reset
    begin
      @package.cat('foo')
      flunk "Cat should have failed"
    rescue
      assert_equal("File 'foo' not a regular file or not readable", $!.message)
    end
  end
  
  def test_task_cd
    # test nominal case
    @package.cd(@tmp_dir)
    expected = @tmp_dir
    actual = Dir.getwd
    assert(File.identical?(expected, actual))
    # test changing to a directory that doesn't exists
    begin
      dir = File.join(@tmp_dir, 'lkjqzcjv')
      @package.cd(dir)
      flunk "Should have raised an error"
    rescue Bee::Util::BuildError
    end
    # test bad arguments
    begin
      @package.cd(Object.new)
      flunk "Should have raised a BuildError"
    rescue Bee::Util::BuildError
      expected = 'cd parameter must be a string'
      actual = $!.message
      assert_equal(expected, actual)
    end
  end

  def test_task_pwd
    # nominal case
    @package.pwd('curdir')
    assert_equal(FileUtils.pwd, @build.context.get_property('curdir'))
    # error case
    begin
      @package.pwd(true)
      flunk 'Should have failed because parameter is bad type'
    rescue
      assert_equal('pwd parameter must be a string', $!.message)
    end
  end

  def test_task_ln
    if not windows?
      # nominal case
      old = File.join(@tmp_dir, 'file.txt')
      create_file(old)
      new = File.join(@tmp_dir, 'file2.txt')    
      params = { 'old' => old, 'new' => new }
      @package.ln(params)
      assert(File.exists?(new))
      assert(File.symlink?(new))
      # error case missing new parameter
      params = { 'old' => old }
      begin
        @package.ln(params)
        flunk 'Should have failed for missing parameters'
      rescue
        assert_equal("ln 'new' parameter is mandatory", $!.message)
      end
      # error case impossible link
      old = File.join(@tmp_dir, 'file.txt')
      create_file(old)
      new = File.join(@tmp_dir, 'file2.txt')
      FileUtils.touch(new)
      params = { 'old' => old, 'new' => new }
      begin
        @package.ln(params)
        flunk 'Should have failed because link is impossible'
      rescue
        assert($!.message =~ /Error making the link: File exists/)
      end
    end
  end
  
  # Test task chmod.
  def test_task_chmod
    if not windows?
      # nominal case
      test_file = File.join(@tmp_dir, 'test.txt')
      File.open(test_file, 'w') { |file| file.write('TEST') }
      params = { 'files'=> test_file, 'mode'=> 0000 }
      @package.chmod(params)
      assert(!File.readable?(test_file))
      assert(!File.writable?(test_file))
      assert(!File.executable?(test_file))
      params = { 'files'=> test_file, 'mode'=> 0100 }
      @package.chmod(params)
      assert(!File.readable?(test_file))
      assert(!File.writable?(test_file))
      assert(File.executable?(test_file))
      params = { 'files'=> test_file, 'mode'=> 0200 }
      @package.chmod(params)
      assert(!File.readable?(test_file))
      assert(File.writable?(test_file))
      assert(!File.executable?(test_file))
      params = { 'files'=> test_file, 'mode'=> 0300 }
      @package.chmod(params)
      assert(!File.readable?(test_file))
      assert(File.writable?(test_file))
      assert(File.executable?(test_file))
      params = { 'files'=> test_file, 'mode'=> 0400 }
      @package.chmod(params)
      assert(File.readable?(test_file))
      assert(!File.writable?(test_file))
      assert(!File.executable?(test_file))
      params = { 'files'=> test_file, 'mode'=> 0500 }
      @package.chmod(params)
      assert(File.readable?(test_file))
      assert(!File.writable?(test_file))
      assert(File.executable?(test_file))
      params = { 'files'=> test_file, 'mode'=> 0600 }
      @package.chmod(params)
      assert(File.readable?(test_file))
      assert(File.writable?(test_file))
      assert(!File.executable?(test_file))
      params = { 'files'=> test_file, 'mode'=> 0700 }
      @package.chmod(params)
      assert(File.readable?(test_file))
      assert(File.writable?(test_file))
      assert(File.executable?(test_file))
      # test decimal format
      params = { 'files'=> test_file, 'mode'=> 320 }
      @package.chmod(params)
      assert(File.readable?(test_file))
      assert(!File.writable?(test_file))
      assert(File.executable?(test_file))
      # test hexa format
      params = { 'files'=> test_file, 'mode'=> 0x40 }
      @package.chmod(params)
      assert(!File.readable?(test_file))
      assert(!File.writable?(test_file))
      assert(File.executable?(test_file))
      # recursive mode
      test_dir = File.join(@tmp_dir, 'test')
      test_file = File.join(test_dir, 'test.txt')
      FileUtils.makedirs(test_dir)
      File.open(test_file, 'w') { |file| file.write('TEST') }
      executable = File.executable?(test_file)
      if executable
        new_mode = 0600
      else
        new_mode = 0700
      end
      params = { 'files'=> test_dir, 'mode'=> new_mode, 'recursive'=> true }
      @package.chmod(params)
      assert(File.readable?(test_file))
      assert(File.writable?(test_file))
      assert(File.executable?(test_file) != executable)
      # error cases
      params = { 'files'=> test_file, 'mode'=> true }
      begin
        @package.chmod(params)
        flunk 'Should have failed'
      rescue Bee::Util::BuildError
        assert_equal($!.message, "chmod 'mode' parameter must be an integer")
      end
      params = { 'files' => true, 'mode'=> 0100 }
      begin
        @package.chmod(params)
        flunk 'Should have failed'
      rescue Bee::Util::BuildError
        assert_equal($!.message,
                     "chmod 'files' parameter must be a string or an array")
      end
      # error case
      params = { 'files' => test_file, 'mode'=> 0100 }
      FileUtils.stubs(:chmod).raises(Exception.new('TEST'))
      assert_raise(Bee::Util::BuildError) { @package.chmod(params) }
    end
  end

  def test_task_chown
    if not windows?
      # nominal case
      test_file = File.join(@tmp_dir, 'test.txt')
      File.open(test_file, 'w') { |file| file.write('TEST') }
      params = { 'user' => 'user', 'group' => 'group', 'files' => test_file }
      FileUtils.expects(:chown).with('user', 'group', [File.expand_path(test_file)])
      @package.chown(params)
      params = { 'user' => 'user', 'group' => 'group', 'files' => test_file, 'recursive' => true }
      FileUtils.expects(:chown_R).with('user', 'group', [File.expand_path(test_file)])
      @package.chown(params)
      # error cases for parameters
      begin
        params = { 'user' => 'test', 'group' => 'test' }
        @package.chown(params)
        flunk 'Should have failed because files parameter is missing'
      rescue Bee::Util::BuildError
        assert_equal("chown 'files' parameter is mandatory", $!.message)
      end
      # error case
      params = { 'user' => 'user', 'group' => 'group', 'files'=> test_file }
      FileUtils.expects(:chown).with('user', 'group', [File.expand_path(test_file)]).raises(Exception.new('TEST'))
      assert_raise(Bee::Util::BuildError) { @package.chown(params) }
    end
  end

  def test_task_mkdir
    # nominal case with a single recursive dir
    dir = File.join(@tmp_dir, 'foo', 'bar')
    @package.mkdir(dir)
    expected = true
    actual = File.exists?(dir) and File.directory?(dir)
    assert_equal(expected, actual)
    # nominal case with a list of directories
    dirs = [File.join(@tmp_dir, 'toto'), File.join(@tmp_dir, 'titi')]
    @package.mkdir(dirs)
    found = Dir.entries(@tmp_dir)
    assert(found.member?('toto'))
    assert(found.member?('titi'))
    # error case
    dir = Object.new
    begin
      @package.mkdir(dir)
      flunk "Should have raised a BuildError"
    rescue Bee::Util::BuildError
      expected = 'mkdir parameter must a String or an array of Strings'
      actual = $!.message
      assert_equal(expected, actual)
    end
    # another error case
    dirs = [File.join(@tmp_dir, 'foo'), Object.new]
    begin
      @package.mkdir(dirs)
      flunk "Should have raised a BuildError"
    rescue Bee::Util::BuildError
      expected = 'mkdir parameter must a String or an array of Strings'
      actual = $!.message
      assert_equal(expected, actual)
    end
    # error case when directory can't be created
    dirs = File.join(@tmp_dir, 'test')
    FileUtils.touch(dirs)
    begin
      @package.mkdir(dirs)
      flunk 'Should have raised a BuildError'
    rescue Bee::Util::BuildError
      assert_match(/Error creating directory/,
                   $!.message)
    end
  end
  
  def test_task_cp
    # nominal case for a src and dest file
    src = File.join(@tmp_dir, 'file.txt')
    create_file(src)
    dest = File.join(@tmp_dir, 'dest.txt')
    @package.cp({ 'src' => src, 'dest' => dest })
    assert_file(dest, src)
    # nominal case for src files and destination directory
    clean_tmp
    src2 = File.join(@tmp_dir, 'file2.txt')
    dest = File.join(@tmp_dir, 'dir')
    create_file(src)
    create_file(src2)
    FileUtils.makedirs(dest)
    @package.cp({ 'src' => [src, src2], 'dest' => dest })
    assert_file(File.join(dest, 'file.txt'), src)
    assert_file(File.join(dest, 'file2.txt'), src2)
    # nominal case for src and dest directory
    clean_tmp
    src = File.join(@tmp_dir, 'dir')
    dest = File.join(@tmp_dir, 'todir')
    FileUtils.makedirs(src)
    FileUtils.makedirs(dest)
    file1 = File.join(src, 'file1.txt')
    file2 = File.join(src, 'file2.txt')
    create_file(file1)
    create_file(file2)
    @package.cp({ 'src' => src, 'dest' => dest })
    assert_file(File.join(dest, 'dir', 'file1.txt'), file1)
    assert_file(File.join(dest, 'dir', 'file2.txt'), file2)
    # error case: dest must be a string
    clean_tmp
    src = File.join(@tmp_dir, 'dir')
    dest = ['foo', 'bar']
    begin
      @package.cp({ 'src' => src, 'dest' => dest })
      flunk "Should have failed because dest must be a string"
    rescue Bee::Util::BuildError
      assert_match("cp 'dest' parameter must be a string", $!.message)
    end
    # error case: can't copy
    clean_tmp
    src = File.join(@tmp_dir, 'file.txt')
    create_file(src)
    dest = File.join(@tmp_dir, 'dest.txt')
    create_file(dest)
    FileUtils.chmod(0000, dest)
    begin
      @package.cp({ 'src' => src, 'dest' => dest })
      flunk "Should have failed because we can't copy"
    rescue Bee::Util::BuildError
      assert_match('Error copying file(s): Permission denied', $!.message)
    end
    FileUtils.chmod(0644, dest)
  end
  
  def test_task_mv
    # nominal case for a src and dest file
    src = File.join(@tmp_dir, 'src.txt')
    create_file(src)
    dest = File.join(@tmp_dir, 'dest.txt')
    @package.mv({ 'src' => src, 'dest' => dest })
    assert_file(dest, src)
    assert(!File.exists?(File.join(@tmp_dir, src)))
    # nominal case with two source files
    clean_tmp
    src = File.join(@tmp_dir, 'src.txt')
    src2 = File.join(@tmp_dir, 'src2.txt')
    dest = File.join(@tmp_dir, 'dir')
    create_file(src)
    create_file(src2)
    FileUtils.makedirs(dest)
    @package.mv({ 'src' => File.join(@tmp_dir, '*.txt'), 'dest' => dest })
    assert_file(File.join(dest, 'src.txt'), src)
    assert_file(File.join(dest, 'src2.txt'), src2)
    assert(!File.exists?(src))
    assert(!File.exists?(src2))
    # nominal case with directory for src and dest
    clean_tmp
    src = File.join(@tmp_dir, 'dir1')
    dest = File.join(@tmp_dir, 'dir2')
    FileUtils.makedirs(src)
    create_file(File.join(src, 'test.txt'))
    @package.mv({ 'src' => src, 'dest' => dest })
    assert(File.exists?(dest))
    assert(File.directory?(dest))
    assert_file(File.join(dest, 'test.txt'), File.join(src, 'test.txt'))
    assert(!File.exists?(src))
    # error case: dest must be a string
    clean_tmp
    src = File.join(@tmp_dir, 'src.txt')
    dest = ['foo', 'bar']
    begin
      @package.mv({ 'src' => src, 'dest' => dest })
      flunk "Should have failed because dest must be a string"
    rescue  Bee::Util::BuildError
      assert_match("mv 'dest' parameter must be a string", $!.message)
    end
    # error case: can't move
    clean_tmp
    src = File.join(@tmp_dir, 'file.txt')
    create_file(src)
    begin
      @package.mv({ 'src' => src, 'dest' => '' })
      flunk "Should have failed because we can't move"
    rescue Bee::Util::BuildError
      assert_match('Error moving file(s): No such file or directory',
                   $!.message)
    end
  end

  def test_task_copy
    # nominal case for a single file
    src_dir = File.join(@tmp_dir, 'src')
    dst_dir = File.join(@tmp_dir, 'dst')
    FileUtils.makedirs(src_dir)
    FileUtils.makedirs(dst_dir)
    src = File.join(src_dir, 'file.txt')
    dst = File.join(src_dir, 'file.txt')
    create_file(src)
    @package.copy({ 'root' => src_dir,
                    'includes' => '*.txt',
                    'dest' => dst_dir })
    assert_file(dst, src)
    # nominal case with flatten
    src_dir = File.join(@tmp_dir, 'src', 'sub')
    dst_dir = File.join(@tmp_dir, 'dst')
    FileUtils.makedirs(src_dir)
    FileUtils.makedirs(dst_dir)
    src = File.join(src_dir, 'file.txt')
    dst = File.join(dst_dir, 'file.txt')
    create_file(src)
    @package.copy({ 'root' => src_dir,
                    'includes' => '*.txt',
                    'dest' => dst_dir,
                    'flatten' => true })
    assert_file(dst, src)
    # error case with root not found
    clean_tmp
    src_dir = File.join(@tmp_dir, 'src')
    dst_dir = File.join(@tmp_dir, 'dst')
    FileUtils.makedirs(dst_dir)
    src = File.join(src_dir, 'file.txt')
    dst = File.join(src_dir, 'file.txt')
    begin
      @package.copy({ 'root' => src_dir,
                      'includes' => '*.txt',
                      'dest' => dst_dir })
      flunk "Should have failed because root directory doesn't exist"
    rescue Bee::Util::BuildError
      assert_equal("copy 'root' parameter must be an existing directory",
                   $!.message)
    end
    # error case with dest not found
    clean_tmp
    src_dir = File.join(@tmp_dir, 'src')
    dst_dir = File.join(@tmp_dir, 'dst')
    FileUtils.makedirs(src_dir)
    src = File.join(src_dir, 'file.txt')
    dst = File.join(src_dir, 'file.txt')
    begin
      @package.copy({ 'root' => src_dir,
                      'includes' => '*.txt',
                      'dest' => dst_dir })
      flunk "Should have failed because dest directory doesn't exist"
    rescue Bee::Util::BuildError
      assert_equal("copy 'dest' parameter must be an existing directory",
                   $!.message)
    end
    # nominal case lenient with dest not found
    clean_tmp
    src_dir = File.join(@tmp_dir, 'src')
    dst_dir = File.join(@tmp_dir, 'dst')
    FileUtils.makedirs(src_dir)
    src = File.join(src_dir, 'file.txt')
    dst = File.join(src_dir, 'file.txt')
    @package.copy({ 'root'     => src_dir,
                    'includes' => '*.txt',
                    'dest'     => dst_dir,
                    'lenient'  => true})
    # nominal case lenient with src not found
    clean_tmp
    src_dir = File.join(@tmp_dir, 'src')
    dst_dir = File.join(@tmp_dir, 'dst')
    FileUtils.makedirs(dst_dir)
    src = File.join(src_dir, 'file.txt')
    dst = File.join(src_dir, 'file.txt')
    @package.copy({ 'root'     => src_dir,
                    'includes' => '*.txt',
                    'dest'     => dst_dir,
                    'lenient'  => true})
  end
  
  def test_task_move
    # nominal case for a single file
    src_dir = File.join(@tmp_dir, 'src')
    dst_dir = File.join(@tmp_dir, 'dst')
    FileUtils.makedirs(src_dir)
    FileUtils.makedirs(dst_dir)
    src = File.join(src_dir, 'file.txt')
    dst = File.join(dst_dir, 'file.txt')
    create_file(src)
    @package.move({ 'root' => src_dir,
                    'includes' => '*.txt',
                    'dest' => dst_dir })
    assert_file(dst, src)
    assert(!File.exists?(src))
    # nominal case with flatten
    src_dir = File.join(@tmp_dir, 'src', 'sub')
    dst_dir = File.join(@tmp_dir, 'dst')
    FileUtils.makedirs(src_dir)
    FileUtils.makedirs(dst_dir)
    src = File.join(src_dir, 'file.txt')
    dst = File.join(dst_dir, 'file.txt')
    create_file(src)
    @package.move({ 'root' => src_dir,
                    'includes' => '*.txt',
                    'dest' => dst_dir,
                    'flatten' => true })
    assert_file(dst, src)
    assert(!File.exists?(src))
    # error case with root not found
    clean_tmp
    src_dir = File.join(@tmp_dir, 'src')
    dst_dir = File.join(@tmp_dir, 'dst')
    FileUtils.makedirs(dst_dir)
    src = File.join(src_dir, 'file.txt')
    dst = File.join(src_dir, 'file.txt')
    begin
      @package.move({ 'root' => src_dir,
                      'includes' => '*.txt',
                      'dest' => dst_dir })
      flunk "Should have failed because root directory doesn't exist"
    rescue Bee::Util::BuildError
      assert_equal("move 'root' parameter must be an existing directory",
                   $!.message)
    end
    # error case with dest not found
    clean_tmp
    src_dir = File.join(@tmp_dir, 'src')
    dst_dir = File.join(@tmp_dir, 'dst')
    FileUtils.makedirs(src_dir)
    src = File.join(src_dir, 'file.txt')
    dst = File.join(src_dir, 'file.txt')
    begin
      @package.move({ 'root' => src_dir,
                      'includes' => '*.txt',
                      'dest' => dst_dir })
      flunk "Should have failed because dest directory doesn't exist"
    rescue Bee::Util::BuildError
      assert_equal("move 'dest' parameter must be an existing directory",
                   $!.message)
    end
    # nominal case lenient with root not found
    clean_tmp
    src_dir = File.join(@tmp_dir, 'src')
    dst_dir = File.join(@tmp_dir, 'dst')
    FileUtils.makedirs(dst_dir)
    src = File.join(src_dir, 'file.txt')
    dst = File.join(src_dir, 'file.txt')
    @package.move({ 'root'     => src_dir,
                    'includes' => '*.txt',
                    'dest'     => dst_dir,
                    'lenient'  => true})
    # error case with dest not found
    clean_tmp
    src_dir = File.join(@tmp_dir, 'src')
    dst_dir = File.join(@tmp_dir, 'dst')
    FileUtils.makedirs(src_dir)
    src = File.join(src_dir, 'file.txt')
    dst = File.join(src_dir, 'file.txt')
    @package.move({ 'root'     => src_dir,
                    'includes' => '*.txt',
                    'dest'     => dst_dir,
                    'lenient'  => true})
  end
  
  def test_task_rm
    # nominal case with a glob
    file = File.join(@tmp_dir, 'test.txt')
    create_file(file)
    @package.rm(File.join(@tmp_dir, file))
    assert(!File.exists?(File.join(@tmp_dir, file)))
    # nominal case with two globs and three files
    clean_tmp
    file1 = File.join(@tmp_dir, 'test1.txt')
    file2 = File.join(@tmp_dir, 'test2.txt')
    file3 = File.join(@tmp_dir, 'test3.log')
    create_file(file1)
    create_file(file2)
    create_file(file3)
    @package.rm([File.join(@tmp_dir, '**/*.txt'), 
    File.join(@tmp_dir, '**/*.log')])
    assert(!File.exists?(file1))
    assert(!File.exists?(file2))
    assert(!File.exists?(file3))
    # error case: parameter must be a string or array of strings
    clean_tmp
    begin
      @package.rm({ 'foo' => 'bar' })
      flunk "Should have failed because parameter must be a string or array"
    rescue Bee::Util::BuildError
      assert_equal("rm parameter is a String or Array of Strings",
                   $!.message)
    end
    begin
      @package.rm(['foo', { 'foo' => 'bar' }])
      flunk "Should have failed because parameter must be a string or array"
    rescue Bee::Util::BuildError
      assert_equal("rm parameter is a String or Array of Strings",
                   $!.message)
    end
    # error case calling rm
    file = File.join(@tmp_dir, 'test.txt')
    create_file(file)
    FileUtils.expects(:rm).with(file).raises(Exception.new('TEST'))
    assert_raise(Bee::Util::BuildError) { @package.rm(file) }
  end
  
  def test_task_rmrf
    # nominal case with one dir
    dir = File.join(@tmp_dir, 'dir')
    FileUtils.makedirs(dir)
    @package.rmdir(dir)
    assert(!File.exists?(dir))
    # nominal case with two dirs
    clean_tmp
    dir1 = File.join(@tmp_dir, 'dir1')
    dir2 = File.join(@tmp_dir, 'dir2')
    FileUtils.makedirs(dir1)
    FileUtils.makedirs(dir2)
    @package.rmdir([dir1, dir2])
    assert(!File.exists?(dir1))
    assert(!File.exists?(dir2))
    # error case: parameter must be a string or array of strings
    clean_tmp
    begin
      @package.rmdir({ 'foo' => 'bar' })
      flunk "Shound have failed because parameter must be a string or array"
    rescue
    end
    begin
      @package.rmdir(['foo', { 'foo' => 'bar' }])
      flunk "Shound have failed because parameter must be a string or array"
    rescue
    end
    # error case calling rm_rf
    file = File.join(@tmp_dir, 'test.txt')
    create_file(file)
    FileUtils.stubs(:rm_rf).with(file).raises(Exception.new('TEST'))
    assert_raise(Bee::Util::BuildError) { @package.rmrf(file) }
    FileUtils.unstub(:rm_rf)
  end
  
  def test_task_touch
    # nominal case for existing file
    file = File.join(@tmp_dir, 'test.txt')
    create_file(file)
    time1 = File.mtime(file)
    Kernel.sleep(1.1)
    @package.touch(file)
    time2 = File.mtime(file)
    assert(time2 > time1)
    # nominal case for non existing file
    file = File.join(@tmp_dir, 'test.txt')
    @package.touch(file)
    assert(File.exists?(file))
    # error cases for bad parameter type
    begin
      @package.touch(true)
    rescue Bee::Util::BuildError
      assert_equal("touch parameter is a String or an Array of Strings",
                   $!.message)
    end
    begin
      @package.touch(['foo', true])
    rescue Bee::Util::BuildError
      assert_equal("touch parameter is a String or an Array of Strings",
                   $!.message)
    end
    # error case exception call FileUtils.touch
    file = File.join(@tmp_dir, 'test.txt')
    create_file(file)
    FileUtils.expects(:touch).raises(Exception.new('TEST'))
    assert_raise(Bee::Util::BuildError) { @package.touch(file) }
  end

  def test_task_find
    # nominal case
    file1 = File.join(@tmp_dir, 'file1.txt')
    file2 = File.join(@tmp_dir, 'file2.txt')
    file3 = File.join(@tmp_dir, 'dir', 'file3.txt')
    create_file(file1)
    create_file(file2)
    create_file(file3)
    @package.find({ 'includes' => "#{File.join(@tmp_dir, '**/*.txt')}",
                    'property' => 'list'})
    actual = @context.get_property('list').sort
    expected = [file1, file2, file3].sort
    assert_equal(expected, actual)
    # nominal case with join
    @package.find({ 'includes' => "#{File.join(@tmp_dir, '**/*.txt')}",
                    'property' => 'list',
                    'join'     => File::PATH_SEPARATOR })
    actual = @context.get_property('list').split(File::PATH_SEPARATOR).sort
    expected = [file1, file2, file3].sort
    assert_equal(expected, actual)
    # nominal case with excludes
    @package.find({ 'includes' => "#{File.join(@tmp_dir, '**/*.txt')}",
                    'excludes' => "**/file2.txt",
                    'property' => 'list'})
    actual = @context.get_property('list').sort
    expected = [file1, file3].sort
    assert_equal(expected, actual)
    # nominal case with root
    @package.find({ 'root'     => @tmp_dir,
                    'includes' => '**/*.txt',
                    'property' => 'list'})
    actual = @context.get_property('list').sort
    expected = ['file1.txt', 'file2.txt', 'dir/file3.txt'].sort
    assert_equal(expected, actual)
    # nominal case with dotfile and no dotmatch
    file4 = File.join(@tmp_dir, '.file4.txt')
    create_file(file4)
    @package.find({ 'includes' => "#{File.join(@tmp_dir, '**/*.txt')}",
                    'property' => 'list'})
    actual = @context.get_property('list').sort
    expected = [file1, file2, file3].sort
    assert_equal(expected, actual)
    # nominal case with dotfile and dotmatch
    file4 = File.join(@tmp_dir, '.file4.txt')
    create_file(file4)
    @package.find({ 'includes' => "#{File.join(@tmp_dir, '**/*.txt')}",
                    'property' => 'list',
                    'dotmatch' => true })
    actual = @context.get_property('list').sort
    expected = [file1, file2, file3, file4].sort
    assert_equal(expected, actual)
  end

  def test_task_yaml_load
    # nominal case
    write_tmp_file('test.yml', 'foo: bar')
    params = { 'file' => File.join(@tmp_dir, 'test.yml'), 'prop' => 'prop' }
    @package.yaml_load(params)
    assert_equal({'foo' => 'bar'}, @context.get_property('prop'))
    # error case
    @build.expects(:context).raises(Exception.new('TEST'))
    assert_raises(Bee::Util::BuildError) { @package.yaml_load(params) }
  end

  def test_task_yaml_dump
    # nominal case
    @context.set_property('prop', {'foo' => 'bar'})
    params = { 'file' => File.join(@tmp_dir, 'test.yml'), 'prop' => 'prop' }
    @package.yaml_dump(params)
    assert_equal({'foo' => 'bar'}, YAML::load(File.read(File.join(@tmp_dir, 'test.yml'))))
    # error case
    @build.expects(:context).raises(Exception.new('TEST'))
    assert_raises(Bee::Util::BuildError) { @package.yaml_dump(params) }
  end

  def test_task_required
    # error when gem not found
    params = { 'library' => 'librarythatdoesntexist', 'message' => 'Error' }
    begin
      @package.required(params)
      flunk 'Should have failed because library was not found'
    rescue Bee::Util::BuildError
      assert_equal('Error', $!.message)
    end
    # nominal case for version < 1.3.0
    old_version = Gem::RubyGemsVersion
    begin
      Gem.send(:remove_const, :RubyGemsVersion) if
        Gem.const_defined?(:RubyGemsVersion)
      Gem.send(:const_set, :RubyGemsVersion, '1.2.0')
      Gem.expects(:activate).with('library', false)
      params = { 'library' => 'library', 'message' => 'Error' }
      @package.required(params)
      # error case for version < 1.3.0
      Gem.send(:remove_const, :RubyGemsVersion) if
        Gem.const_defined?(:RubyGemsVersion)
      Gem.send(:const_set, :RubyGemsVersion, '1.2.0')
      Gem.expects(:activate).with('library', false).raises(LoadError.new('TEST'))
      params = { 'library' => 'library', 'message' => 'Error' }
      assert_raise(Bee::Util::BuildError) { @package.required(params) }
    ensure
      Gem.send(:remove_const, :RubyGemsVersion) if
        Gem.const_defined?(:RubyGemsVersion)
      Gem.send(:const_set, :RubyGemsVersion, old_version)
    end
  end

  def test_task_test
    # error case: bad parameter type
    params = { 'includes' => true }
    begin
      @package.test(params)
    rescue Bee::Util::BuildError
      assert_equal("test 'includes' parameter must be a string", $!.message)
    end
    if Bee::VersionDependant::ruby_lower_than('1.9.2')
      # nominal case
      test_file = 'tc_test.rb'
      path = write_tmp_file(test_file, "require 'test/unit'")
      params = {
        'root'     => @tmp_dir,
        'includes' => "#{test_file}",
        'dir'      => @tmp_dir,
      }
      runner = mock
      Bee::Task::Default.any_instance.expects(:load).with(path)
      Test::Unit::AutoRunner.expects(:new).with(false).returns(runner)
      runner.expects(:run).returns(true)
      @package.test(params)
      # error case when test fails
      test_file = 'tc_test.rb'
      path = write_tmp_file(test_file, "require 'test/unit'")
      params = {
        'root'     => @tmp_dir,
        'includes' => "#{test_file}",
        'dir'      => @tmp_dir,
      }
      runner = mock
      Bee::Task::Default.any_instance.expects(:load).with(path)
      Test::Unit::AutoRunner.expects(:new).with(false).returns(runner)
      runner.expects(:run).returns(false)
      assert_raise(Bee::Util::BuildError) { @package.test(params) }
    end
    # error case when dir not found
    test_file = 'tc_test.rb'
    path = write_tmp_file(test_file, "require 'test/unit'")
    params = {
      'root'     => @tmp_dir,
      'includes' => "#{test_file}",
      'dir'      => 'foo',
    }
    assert_raise(Bee::Util::BuildError) { @package.test(params) }
  end

  def test_task_erb
    # nominal case in property
    @context.set_property('test', 'TEST')
    source = 'This is a <%= test %>'
    @package.erb({ 'source' => source, 'property' => 'result', 'options' => '%' })
    actual = @context.get_property(:result)
    expected = 'This is a TEST'
    assert_equal(expected, actual)
    # nominal case with dest in file
    file = File.join(@tmp_dir, 'file.txt')
    @package.erb({ 'source' => source, 'dest' => file })
    actual = File.read(file)
    expected = 'This is a TEST'
    assert_equal(expected, actual)
    # nominal case with source file
    path = write_tmp_file('test.erb', 'This is a <%= test %>')
    @package.erb({ 'src' => path, 'property' => 'result', 'options' => '%' })
    actual = @context.get_property(:result)
    expected = 'This is a TEST'
    assert_equal(expected, actual)
    # error case: source parameter must be a string
    begin
      @package.erb({ 'source' => [source], 'property' => 'result' })
      flunk "should have failed because source parameter must be a string"
    rescue
    end
    # error case: src parameter must be a string
    begin
      @package.erb({ 'src' => [source], 'property' => 'result' })
      flunk "should have failed because src parameter must be a string"
    rescue
    end
    # error case: dest parameter must be a string
    begin
      @package.erb({ 'src' => 'src', 'dest' => ['dest'] })
      flunk "should have failed"
    rescue
    end
    # error case: property parameter must be a string
    begin
      @package.erb({ 'src' => 'src', 'property' => ['result'] })
      flunk "should have failed"
    rescue
    end
    # error case: at least src or source parameter
    begin
      @package.erb({ 'dest' => 'dest' })
      flunk "should have failed"
    rescue
    end
    # error case: at least dest or property parameter
    begin
      @package.erb({ 'src' => 'src' })
      flunk "should have failed"
    rescue
    end
    # error case: error in erb source
    source = 'This is a test <%= foo %>'
    begin
      @package.erb({ 'source' => source, 'property' => 'result' })
      flunk "should have failed"
    rescue
    end
    # error case: can't write dest file
    dir = File.join(@tmp_dir, 'dir')
    FileUtils.mkdir(dir)
    params = {
      'source' => 'test',
      'dest' => ''
    }
    assert_raise(Bee::Util::BuildError) { @package.erb(params) }
  end

  def test_task_rdoc
    includes = "'#{__FILE__}'"
    dest = File.join(@tmp_dir, 'rdoc')
    options = '-q'
    @package.rdoc({'includes' => includes, 
                   'dest' => dest, 
                   'options' => options})
    assert(File.exists?(File.join(dest, 'index.html')))
    # error case: dest must be a string
    begin
      @package.rdoc({'includes' => includes, 'dest' => [dest]})
      flunk "Should have failed"
    rescue
    end
    # error case while running rdoc
    dest = File.join(@tmp_dir, 'rdoc')
    params = {
      'includes' => includes,
      'dest'     => dest,
      'options'  => '-q',
    }
    RDoc::RDoc.any_instance.expects(:document).raises(Exception.new('TEST'))
    assert_raise(Bee::Util::BuildError) { @package.rdoc(params) }
  end
  
  def test_task_gem
    # error case: bad paramater type
    begin
      @package.gem(true)
    rescue Bee::Util::BuildError
      assert_equal("gem parameter must be an existing file", $!.message)
    end
    # error case: file that doesn't exist
    begin
      @package.gem('foo')
    rescue Bee::Util::BuildError
      assert_equal("gem parameter must be an existing file", $!.message)
    end
    # error case: bad descriptor (missing version)
    descriptor = "require 'rubygems'
remove_const(:SPEC) if defined?(SPEC)
SPEC = Gem::Specification.new do |spec|
  spec.name = 'name'
end"
    desc_file = File.join(@tmp_dir, 'desc')
    File.open(desc_file, 'wb') { |file| file.write(descriptor) }
    current_dir = Dir.pwd
    Dir.chdir(@tmp_dir)
    begin
      no_output { @package.gem(desc_file) }
    rescue Bee::Util::BuildError
      assert_match(/^Error generating Gem:/, $!.message)
    ensure
      Dir.chdir(current_dir)
    end
    # nominal case
    descriptor = "require 'rubygems'
remove_const(:SPEC) if defined?(SPEC)
SPEC = Gem::Specification.new do |spec|
  spec.name = 'name'
  spec.version = '1.0.0'
  spec.summary = 'summary'
  spec.authors = 'authors'
end"
    desc_file = File.join(@tmp_dir, 'desc')
    File.open(desc_file, 'wb') { |file| file.write(descriptor) }
    current_dir = Dir.pwd
    Dir.chdir(@tmp_dir)
    begin
      no_output { @package.gem(desc_file) }
    ensure
      Dir.chdir(current_dir)
    end
  end

  def test_task_bee
    # nominal case
    build_file = File.join(@tmp_dir, 'build.yml')
    build_src = '
- build: test
  default: foo

- target: foo
  script:
    - print: "foo"
- target: bar
  script:
    - print: "bar"
- target: prop
  script:
    - print: :foo
'
    File.open(build_file, 'w') { |file| file.write(build_src) }
    params = { 'file'=> build_file }
    @listener.reset
    @package.bee(params)
    assert(@listener.output.strip == 'foo')
    params = { 'file'=> build_file, 'target'=> 'bar' }
    @listener.reset
    @package.bee(params)
    assert(@listener.output.strip == 'bar')
    @context.set_property('foo', 'bar')
    params = { 'file'=> build_file, 'target'=> 'prop', 'properties'=> true }
    @listener.reset
    @package.bee(params)
    assert(@listener.output.strip == 'bar')
    # build failure
    params = { 'file'=> build_file, 'target'=> 'prop', 'properties'=> false }
    @listener.reset
    assert_raise(Bee::Util::BuildError) { @package.bee(params) }
    assert(@listener.error?)
    assert(@listener.errors[0].message == "Property 'foo' was not set")
    @listener.reset
    begin
      @package.bee(params)
      flunk "Build should have raised an exception"
    rescue Bee::Util::BuildError
      assert($!.message =~ /Property 'foo' was not set$/)
    end
    # parameter error
    params = { 'file'=> true }
    begin
      @package.bee(params)
      fail 'Should have failed because parameter file must be a String'
    rescue Bee::Util::BuildError
      assert_equal($!.message, "bee 'file' parameter must be a string")
    end
    params = { 'target'=> true }
    begin
      @package.bee(params)
      fail 'Should have failed because parameter target must be a String'
    rescue Bee::Util::BuildError
      assert_equal($!.message, "bee 'target' parameter must be a string or an array")
    end
  end

  ######################################################################
  #                            ARCHIVE TASKS                           #
  ######################################################################
  
  def test_task_zip
    file1 = File.join(@tmp_dir, 'file1.txt')
    file2 = File.join(@tmp_dir, 'file2.txt')
    File.open(file1, 'w') {|file| file.write('File 1')}
    File.open(file2, 'w') {|file| file.write('File 2')}
    includes = "#{@tmp_dir}/*.txt"
    dest = File.join(@tmp_dir, 'test.zip')
    @package.zip({'includes' => includes, 'dest' => dest, 'prefix' => 'test'})
    # error case: dest must be a string
    begin
      @package.zip({'includes' => includes, 'dest' => [dest]})
      flunk "Shoud have failed"
    rescue Bee::Util::BuildError
      assert_equal("zip 'dest' parameter must be a string", $!.message)
    end
    # error case: prefix must be a string
    begin
      @package.zip({'includes' => includes, 
                     'dest' => dest, 
                     'prefix' => ['test']})
      flunk "Shoud have failed"
    rescue Bee::Util::BuildError
      assert_equal("zip 'prefix' parameter must be a string", $!.message)
    end
    # error case calling ZipFile
    file1 = File.join(@tmp_dir, 'file1.txt')
    file2 = File.join(@tmp_dir, 'file2.txt')
    File.open(file1, 'w') {|file| file.write('File 1')}
    File.open(file2, 'w') {|file| file.write('File 2')}
    includes = "#{@tmp_dir}/*.txt"
    dest = File.join(@tmp_dir, 'test.zip')
    Zip::ZipFile.expects(:open).raises(Exception.new('TEST'))
    params = {'includes' => includes, 'dest' => dest, 'prefix' => 'test'}
    assert_raise(Bee::Util::BuildError) { @package.zip(params) }

  end
  
  def test_task_unzip
    # nominal case
    write_tmp_file('file1.txt', 'File 1')
    write_tmp_file(File.join('dir', 'file2.txt'), 'File 2')
    dest = File.join(@tmp_dir, 'test.zip')
    params = {
      'root'     => @tmp_dir,
      'includes' => '**/*',
      'dest'     => dest,
      'prefix'   => 'test'
    }
    @package.zip(params)
    Zip::ZipFile.open(dest, Zip::ZipFile::CREATE) do |zip|
      zip.add('test/dir', File.join(@tmp_dir, 'dir'))
      zip.close
    end
    params = { 'src' => dest, 'dest' => @tmp_dir }
    @package.unzip(params)
    assert(File.exists?(File.join(@tmp_dir, 'test', 'file1.txt')))
    assert(File.exists?(File.join(@tmp_dir, 'test', 'dir', 'file2.txt')))
    # error case: src must ba an existing file
    begin
      @package.unzip({'src' => 'foo', 'dest' => dest })
      flunk "Shoud have failed"
    rescue Bee::Util::BuildError
      assert_equal("unzip 'src' parameter must be an readable ZIP archive",
                   $!.message)
    end
    # error case calling ZipFile.foreach
    zip_file = write_tmp_file('test.zip', 'zip file')
    params = { 'src' => zip_file, 'dest' => @tmp_dir }
    Zip::ZipFile.expects(:foreach).raises(Exception.new('TEST'))
    assert_raise(Bee::Util::BuildError) { @package.unzip(params) }
  end
  
  def test_task_tar
    # nominal case
    write_tmp_file('file1.txt', 'File 1')
    write_tmp_file('file2.txt', 'File 2')
    dest = File.join(@tmp_dir, 'test.zip')
    @package.tar({'root' => @tmp_dir, 'includes' => '*', 'dest' => dest})
    # error case: dest must be a string
    begin
      @package.tar({'includes' => '*', 'dest' => true})
      flunk "Shoud have failed"
    rescue Bee::Util::BuildError
      assert_equal("tar 'dest' parameter must be a string", $!.message)
    end
    # error case calling tar
    write_tmp_file('file1.txt', 'File 1')
    write_tmp_file('file2.txt', 'File 2')
    dest = File.join(@tmp_dir, 'test.zip')
    Archive::Tar::Minitar::Output.expects(:open).raises(Exception.new('TEST'))
    params = {'root' => @tmp_dir, 'includes' => '*', 'dest' => dest}
    assert_raise(Bee::Util::BuildError) { @package.tar(params) }
  end

  def test_task_gzip
    # nominal case
    src = File.join(@tmp_dir, 'file.txt')
    File.open(src, 'w') {|file| file.write('File')}
    dest = File.join(@tmp_dir, 'file.gzip')
    @package.gzip({'src' => src, 'dest' => dest})
    # error case: dest must be a string
    begin
      @package.gzip({'src' => file, 'dest' => [dest]})
      flunk "Shoud have failed"
    rescue
    end
    # error case calling gzip
    src = File.join(@tmp_dir, 'file.txt')
    File.open(src, 'w') {|file| file.write('File')}
    dest = File.join(@tmp_dir, 'file.gzip')
    Zlib::GzipWriter.expects(:new).raises(Exception.new('TEST'))
    params = {'src' => src, 'dest' => dest}
    assert_raise(Bee::Util::BuildError) { @package.gzip(params) }
  end

  def test_task_gunzip
    # nominal case
    src = File.join(@tmp_dir, 'file.txt')
    File.open(src, 'w') {|file| file.write('test')}
    dest = File.join(@tmp_dir, 'file.txt.gz')
    @package.gzip({'src' => src, 'dest' => dest})
    assert(File.exists?(dest))
    File.delete(src)
    @package.gunzip({'src' => dest })
    assert(File.exists?(src))
    # nominal case
    src = File.join(@tmp_dir, 'file.txt')
    File.open(src, 'w') {|file| file.write('test')}
    dest = File.join(@tmp_dir, 'file.txt.gzip')
    @package.gzip({'src' => src, 'dest' => dest})
    assert(File.exists?(dest))
    File.delete(src)
    @package.gunzip({'src' => dest })
    assert(File.exists?(src))
    # nominal case
    src = File.join(@tmp_dir, 'file.tar')
    File.open(src, 'w') {|file| file.write('test')}
    dest = File.join(@tmp_dir, 'file.tgz')
    @package.gzip({'src' => src, 'dest' => dest})
    assert(File.exists?(dest))
    File.delete(src)
    @package.gunzip({'src' => dest })
    assert(File.exists?(src))
    # error case: src must ba an existing file
    begin
      @package.gunzip({'src' => 'foo', 'dest' => dest })
      flunk "Shoud have failed"
    rescue Bee::Util::BuildError
      assert_equal("gunzip 'src' parameter must be an readable GZIP archive",
                   $!.message)
    end
    # error case: can't guess destination file
    begin
      src = File.join(@tmp_dir, 'file.txt')
      File.open(src, 'w') {|file| file.write('test')}
      dest = File.join(@tmp_dir, 'file.toto')
      @package.gzip({'src' => src, 'dest' => dest})
      assert(File.exists?(dest))
      File.delete(src)
      @package.gunzip({'src' => dest })
      flunk "Shoud have failed"
    rescue Bee::Util::BuildError
      assert_equal("gunzip can't guess 'dest' parameter from 'src' file name",
                   $!.message)
    end
    # error case calling unzip
    src = File.join(@tmp_dir, 'file.txt')
    File.open(src, 'w') {|file| file.write('test')}
    dest = File.join(@tmp_dir, 'file.txt.gz')
    @package.gzip({'src' => src, 'dest' => dest})
    Zlib::GzipReader.expects(:open).raises(Exception.new('TEST'))
    assert_raise(Bee::Util::BuildError) { @package.gunzip({'src' => dest }) }
  end
  
  def test_task_targz
    # nominal case
    file1 = File.join(@tmp_dir, 'file1.txt')
    file2 = File.join(@tmp_dir, 'file2.txt')
    File.open(file1, 'w') {|file| file.write('File 1')}
    File.open(file2, 'w') {|file| file.write('File 2')}
    dest = File.join(@tmp_dir, 'test.zip')
    @package.targz({'root' => @tmp_dir, 'includes' => '*', 'dest' => dest})
    # error case: dest must be a string
    begin
      @package.targz({'includes' => '*', 'dest' => true})
      flunk "Shoud have failed"
    rescue
    end
    # error case calling tar
    file1 = File.join(@tmp_dir, 'file1.txt')
    file2 = File.join(@tmp_dir, 'file2.txt')
    File.open(file1, 'w') {|file| file.write('File 1')}
    File.open(file2, 'w') {|file| file.write('File 2')}
    dest = File.join(@tmp_dir, 'test.zip')
    Zlib::GzipWriter.expects(:new).raises(Exception.new('TEST'))
    params = {'root' => @tmp_dir, 'includes' => '*', 'dest' => dest}
    assert_raise(Bee::Util::BuildError) { @package.targz(params) }
  end

  def test_task_untar
    # nominal case
    file1 = File.join(@tmp_dir, 'file1.txt')
    file2 = File.join(@tmp_dir, 'dir', 'file2.txt')
    Dir.mkdir(File.join(@tmp_dir, 'dir'))
    File.open(file1, 'w') {|file| file.write('File 1')}
    File.open(file2, 'w') {|file| file.write('File 2')}
    dest = File.join(@tmp_dir, 'test.tar')
    params = { 'root' => @tmp_dir, 'includes' => '**/*.txt', 'dest' => dest }
    @package.tar(params)
    File.delete(file1)
    File.delete(file2)
    params = { 'src' => dest, 'dest' => @tmp_dir }
    @package.untar(params)
    assert(File.exists?(file1))
    assert(File.exists?(file2))
    # nominal case with targz
    @package.gzip({'src' => dest})
    params = { 'src' => "#{dest}.gz", 'dest' => @tmp_dir }
    @package.untar(params)
    assert(File.exists?(file1))
    assert(File.exists?(file2))
    # error case: src must ba an existing file
    begin
      @package.untar({'src' => 'foo', 'dest' => dest })
      flunk "Shoud have failed"
    rescue Bee::Util::BuildError
      assert_equal("untar 'src' parameter must be an readable TAR archive",
                   $!.message)
    end
    # error case when calling untar
    clean_tmp
    file1 = File.join(@tmp_dir, 'file1.txt')
    file2 = File.join(@tmp_dir, 'dir', 'file2.txt')
    Dir.mkdir(File.join(@tmp_dir, 'dir'))
    File.open(file1, 'w') {|file| file.write('File 1')}
    File.open(file2, 'w') {|file| file.write('File 2')}
    dest = File.join(@tmp_dir, 'test.tar')
    params = { 'root' => @tmp_dir, 'includes' => '**/*.txt', 'dest' => dest }
    @package.tar(params)
    File.delete(file1)
    File.delete(file2)
    params = { 'src' => dest, 'dest' => @tmp_dir }
    Archive::Tar::Minitar.expects(:unpack).raises(Exception.new('TEST'))
    assert_raise(Bee::Util::BuildError) { @package.untar(params) }
  end

  def test_ftp_login
    # nominal case
    params = {
      'username' => 'username',
      'password' => 'password',
      'host'     => 'host',
    }
    ftp = mock
    Net::FTP.expects(:open).with(params['host']).returns(ftp).yields(ftp)
    ftp.expects(:login).with(params['username'], params['password'])
    ftp.expects(:close)
    @package.ftp_login(params)
    # error case calling ftp
    params = {
      'username' => 'username',
      'password' => 'password',
      'host'     => 'host',
    }
    ftp = mock
    Net::FTP.expects(:open).with(params['host']).raises(Exception.new('TEST'))
    assert_raise(Bee::Util::BuildError) { @package.ftp_login(params) }
  end

  def test_ftp_get
    # nominal case
    params = {
      'username' => 'username',
      'password' => 'password',
      'host'     => 'host',
      'file'     => 'file',
    }
    ftp = mock
    Net::FTP.expects(:open).with(params['host']).returns(ftp).yields(ftp)
    ftp.expects(:login).with(params['username'], params['password'])
    ftp.expects(:getbinaryfile).with(params['file'], params['file'])
    ftp.expects(:close)
    @package.ftp_get(params)
    # nominal case in text mode
    params = {
      'username' => 'username',
      'password' => 'password',
      'host'     => 'host',
      'file'     => 'file',
      'binary'   => false,
    }
    ftp = mock
    Net::FTP.expects(:open).with(params['host']).returns(ftp).yields(ftp)
    ftp.expects(:login).with(params['username'], params['password'])
    ftp.expects(:gettextfile).with(params['file'], params['file'])
    ftp.expects(:close)
    @package.ftp_get(params)
    # error case calling ftp
    params = {
      'username' => 'username',
      'password' => 'password',
      'host'     => 'host',
      'file'     => 'file',
    }
    ftp = mock
    Net::FTP.expects(:open).with(params['host']).raises(Exception.new('TEST'))
    assert_raise(Bee::Util::BuildError) { @package.ftp_get(params) }
  end

  def test_ftp_put
    # nominal case
    params = {
      'username' => 'username',
      'password' => 'password',
      'host'     => 'host',
      'file'     => 'file',
    }
    ftp = mock
    Net::FTP.expects(:open).with(params['host']).returns(ftp).yields(ftp)
    ftp.expects(:login).with(params['username'], params['password'])
    ftp.expects(:putbinaryfile).with(params['file'], nil)
    ftp.expects(:close)
    @package.ftp_put(params)
    # nominal case in text mode
    params = {
      'username' => 'username',
      'password' => 'password',
      'host'     => 'host',
      'file'     => 'file',
      'binary'   => false,
    }
    ftp = mock
    Net::FTP.expects(:open).with(params['host']).returns(ftp).yields(ftp)
    ftp.expects(:login).with(params['username'], params['password'])
    ftp.expects(:puttextfile).with(params['file'], nil)
    ftp.expects(:close)
    @package.ftp_put(params)
    # error case calling ftp
    params = {
      'username' => 'username',
      'password' => 'password',
      'host'     => 'host',
      'file'     => 'file',
    }
    ftp = mock
    Net::FTP.expects(:open).with(params['host']).raises(Exception.new('TEST'))
    assert_raise(Bee::Util::BuildError) { @package.ftp_put(params) }
  end

  def test_ftp_mkdir
    # nominal case
    params = {
      'username' => 'username',
      'password' => 'password',
      'host'     => 'host',
      'dir'      => 'dir',
    }
    ftp = mock
    Net::FTP.expects(:open).with(params['host']).returns(ftp).yields(ftp)
    ftp.expects(:login).with(params['username'], params['password'])
    ftp.expects(:mkdir).with(params['dir'])
    ftp.expects(:close)
    @package.ftp_mkdir(params)
    # error case calling ftp
    params = {
      'username' => 'username',
      'password' => 'password',
      'host'     => 'host',
      'dir'      => 'dir',
    }
    ftp = mock
    Net::FTP.expects(:open).with(params['host']).raises(Exception.new('TEST'))
    assert_raise(Bee::Util::BuildError) { @package.ftp_mkdir(params) }
  end

end
