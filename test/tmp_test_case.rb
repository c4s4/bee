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
require 'bee_test_case'
require 'tmpdir'

# Test case that creates a 'tmp' directory before each test and deletes it
# after. Also disable tests if we can't write on disk (if we run tests while
# installing with gem in a system directory for instance).
class TmpTestCase < BeeTestCase

  # Temporary directory prefix.
  TMP_DIR_PREFIX = 'bee-test-'

  # Constructor: disable test if we don't have write permission.
  def initialize(*args)
    super(*args)
    @script_dir = File.expand_path(File.dirname(__FILE__))
    @working_dir = Dir.getwd
    @tmp_dir = Dir.mktmpdir(TMP_DIR_PREFIX)
    begin
      FileUtils.makedirs(@tmp_dir)
      @run_tests = true
    rescue
      @run_tests = false
      methods = self.class.public_instance_methods
      for method in methods
        self.class.remove_method(Symbol.new(method)) if method =~ /^test_.*/
      end
    end
  end
  
  # Run before any test: create temporary directory.
  def setup
    FileUtils.makedirs(@tmp_dir)
  end
  
  # Run after any test: delete temporary directory.
  def teardown
    Dir.chdir(@working_dir)
    FileUtils.rm_rf(@tmp_dir)
  end

  # Write a file in tmp directory:
  # - file: the file name to write.
  # - text: the text of the file to write.
  # Return the created file name.
  def write_tmp_file(file, text)
    path = File.join(@tmp_dir, file)
    if File.dirname(file) != '.'
      FileUtils.makedirs(File.join(@tmp_dir, File.dirname(file)))
    end
    File.open(path, 'w') do |f|
      f.write(text)
    end
    return path
  end

  # Clean temporary directory.
  def clean_tmp
    FileUtils.rm_rf(@tmp_dir)
    FileUtils.makedirs(@tmp_dir)
  end

  # Create a given file in tmp directory with its name as contents.
  # - name: file name, relative to temporary directory.
  def create_file(name)
    dir = File.dirname(name)
    FileUtils.makedirs(dir)
    File.open(name, 'wb') { |file| file.write(name) }
  end

  # Assert file exists and test its contents.
  def assert_file(file, contents)
    assert(File.exists?(file))
    text = File.read(file)
    assert_equal(contents, text)
  end

  # Execute a block capturing output.
  def no_output(&block)
    file = File.join(@tmp_dir, 'output')
    begin
      old_stdout = STDOUT.dup
      old_stderr = STDERR.dup
      STDOUT.reopen(file)
      STDERR.reopen(file)
      yield(block)
    ensure
      STDOUT.reopen(old_stdout)
      STDERR.reopen(old_stderr)
    end
  end
  
  def test_
  end

end
