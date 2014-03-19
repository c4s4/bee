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
$:.unshift(File.dirname(__FILE__))
require 'tmp_test_case'
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'bee_console'
require 'bee_task_default'
require 'highline'

class TestTemplates < TmpTestCase

  def test_template_application
    run_template('application', ['foo'])
    buildfile = File.join(@tmp_dir, 'foo', 'build.yml')
    assert(File.exists?(buildfile))
    # replace test task with a simple print and set properties
    source = open(buildfile) { |f| f.read() }
    source.gsub!(/- test:.*?:test_dir/m, '- print: "Testing..."')
    source = set_property(source, 'version', '0.0.1')
    source = set_property(source, 'author', 'author')
    source = set_property(source, 'years', '2006-2011')
    source = set_property(source, 'summary', 'summary')
    source = set_property(source, 'description', 'description')
    source = set_property(source, 'email', 'email')
    source = set_property(source, 'homepage', 'http://www.homepage.com')
    source = set_property(source, 'rubyforge', 'rubyforge')
    open(buildfile, 'w') { |f| f.write(source) }
    # run builds on application project
    assert_build_run(buildfile, /Testing\.\.\..*?OK/m, 'test')
    assert_build_run(buildfile, /.*?OK/m, 'gem')
    assert(File.exists?(File.join(@tmp_dir, 'foo', 'build', 'foo-0.0.1.gem')))
    if Bee::VersionDependant::ruby_lower_than('1.9.2')
      assert_build_run(buildfile, /Generating HTML\.\.\..*?Files:   1.*?OK/m, 'api')
      assert(File.exists?(File.join(@tmp_dir, 'foo', 'build', 'api', 'index.html')))
    end
    assert_build_run(buildfile, /Building ZIP archive/, 'zip')
    assert(File.exists?(File.join(@tmp_dir, 'foo', 'build', 'foo-0.0.1.zip')))
    assert_build_run(buildfile, /OK/, ['clean'])
  end

  def test_template_package
    run_template('package', ['foo'])
    buildfile = File.join(@tmp_dir, 'bee_foo', 'build.yml')
    assert(File.exists?(buildfile))
    # replace test task with a simple print and set properties
    source = open(buildfile) { |f| f.read() }
    source.gsub!(/- test:.*?:test_dir/m, '- print: "Testing..."')
    source = set_property(source, 'version', '0.0.1')
    source = set_property(source, 'author', 'author')
    source = set_property(source, 'years', '2006-2011')
    source = set_property(source, 'summary', 'summary')
    source = set_property(source, 'description', 'description')
    source = set_property(source, 'email', 'email')
    source = set_property(source, 'homepage', 'http://www.homepage.com')
    source = set_property(source, 'rubyforge', 'rubyforge')
    open(buildfile, 'w') { |f| f.write(source) }
    # run builds on package project
    assert_build_run(buildfile, /Testing\.\.\..*?OK/m, 'test')
    assert_build_run(buildfile, /.*?OK/m, 'gem')
    assert(File.exists?(File.join(@tmp_dir, 'bee_foo', 'build', 'bee_foo-0.0.1.gem')))
    assert_build_run(buildfile, /OK/, ['clean'])
  end

  def test_template_script
    run_template('script', [''])
    buildfile = File.join(@tmp_dir, 'script', 'build.yml')
    assert(File.exists?(buildfile))
    # run builds on script project
    assert_build_run(buildfile, /Building ZIP archive/, 'zip')
    assert(File.exists?(File.join(@tmp_dir, 'script', 'build', 'script-0.0.1.zip')))
    assert_build_run(buildfile, /OK/, ['clean'])
    assert(!File.exists?(File.join(@tmp_dir, 'script', 'build')))
  end

  def test_template_sinatra
    run_template('sinatra', ['foo'])
    buildfile = File.join(@tmp_dir, 'foo', 'build.yml')
    assert(File.exists?(buildfile))
    # run builds on script project
    assert_build_run(buildfile, /Building ZIP archive/, 'zip')
    assert(File.exists?(File.join(@tmp_dir, 'foo', 'build', 'foo-0.0.1.zip')))
    assert_build_run(buildfile, /OK/, ['clean'])
    assert(!File.exists?(File.join(@tmp_dir, 'foo', 'build')))
  end

  def test_template_source
    run_template('source', [''])
    source = File.join(@tmp_dir, 'source.rb')
    assert(File.exists?(source))
  end

  def test_template_xmlrpc
    run_template('xmlrpc', ['bar'])
    buildfile = File.join(@tmp_dir, 'bar', 'build.yml')
    assert(File.exists?(buildfile))
    # run builds on script project
    assert_build_run(buildfile, /Building ZIP archive/, 'zip')
    assert(File.exists?(File.join(@tmp_dir, 'bar', 'build', 'bar-0.0.1.zip')))
    assert_build_run(buildfile, /OK/, ['clean'])
    assert(!File.exists?(File.join(@tmp_dir, 'bar', 'build')))
  end

  ##############################################################################
  #                             UTILITY METHODS                                #
  ##############################################################################

  def run_template(name, input=[], silent=true)
    """Run a given template with passed input:
    - name: the name of the template to run.
    - input: input as a string or array of strings."""
    current_dir = Dir.pwd
    begin
      Dir.chdir(@tmp_dir)
      build_file = File.join(@script_dir, '..', 'egg', "#{name}.yml")
      input = Array(input)
      for string in input
        HighLine.any_instance.expects(:ask).returns(string)
      end
      run_silently_or_not(silent) do
        Bee::Console.start_command_line(['-f', build_file])
      end
    rescue Exception
      puts $!
      puts $!.backtrace
    ensure
      Dir.chdir(current_dir)
    end
  end

  def run_silently_or_not(silent, &block)
    if silent
      run_silently(&block)
    else
      yield block
    end
  end

  def set_property(source, property, value)
    return source.gsub(/#{property}:.*?""/, "#{property}: '#{value}'")
  end

  def assert_build_run(buildfile, pattern, targets)
    """Run a given build and assert output matches a pattern:
    - buildfile: absolute path of the build file to run.
    - pattern: the pattern that must match output.
    - targets: targets to run as a string."""
    current_dir = Dir.pwd
    begin
      Dir.chdir(@tmp_dir)
      bee_script = File.join(@script_dir, '..', 'bin', 'bee')
      target_list = Array(targets).join(' ')
      output = `ruby #{bee_script} -f #{buildfile} #{target_list} 2>&1`
      raise "Error running build" if $? != 0
      assert_match(pattern, output)
    ensure
      Dir.chdir(current_dir)
    end    
  end

end

