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
require 'mocha/setup'
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'bee_util'

# Test case that provides utility methods.
class BeeTestCase < Test::Unit::TestCase

  # Tells if Bee is available.
  def bee_available?
    if Bee::Util::gem_available?('bee')
      resource = ":bee:bin/bee"
      path = Bee::Util::absolute_path(resource)
      return File.exists?(path)
    else
      return false
    end
  end

  # Runs a block silently (without output)
  def run_silently(&block)
    stdout = $stdout
    stderr = $stderr
    output = StringIO.new
    $stdout = $stderr = output
    begin
      yield block
    ensure
      output.close
      $stdout = stdout
      $stderr = stderr
    end
  end

  # Runs a block silently and assert output against pattern
  def assert_output(pattern, &block)
    stdout = $stdout
    stderr = $stderr
    output = StringIO.new
    $stdout = $stderr = output
    begin
      yield block
    rescue Exception
      puts $!
      puts $!.backtrace
    ensure
      output.close
      $stdout = stdout
      $stderr = stderr
    end
    assert_match(pattern, output.string, "Ouput doesn't match pattern")
  end

  # Run a build and make assertions on output.
  def assert_build(pattern, arguments=[], exception=false, &block)
    """Run a given build file and assert that output matches a pattern."""
    if block
      source = yield block
    else
      source = ''
    end
    assert_output(pattern) do
      path = write_tmp_file('build.yml', source)
      arguments = ['-f', path] + arguments
      if exception
        assert_raise(exception) { Bee::Console.start_command_line(arguments) }
      else
        begin
          Bee::Console.start_command_line(arguments)
        rescue Exception
          raise "Error: an exception was raised: #{$!}"
        end
      end
    end
  end

  # Run a build file and make assertions on output.
  def assert_build_file(buildfile, pattern, arguments=[], exception=false)
    """Run a given build file and assert that output matches a pattern."""
    assert_output(pattern) do
      arguments = ['-f', buildfile] + arguments
      if exception
        assert_raise(exception) { Bee::Console.start_command_line(arguments) }
      else
        Bee::Console.start_command_line(arguments)
      end
    end
  end

  # Tells if we are running under Windows.
  def windows?
    return RUBY_PLATFORM =~ /(mswin|ming)/
  end

  def test_
  end

  private

end
