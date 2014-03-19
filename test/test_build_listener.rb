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

class TestBuildListener

  attr_reader :formatter
  attr_reader :started
  attr_reader :finished
  attr_reader :targets
  attr_reader :tasks
  attr_reader :successful
  attr_reader :errors
  attr_accessor :prompt
  
  def initialize()
    reset
  end

  def start(build, dry=false)
    @started = true
  end

  def stop()
    @finished = true
  end

  def target(target)
    @targets << target
  end

  def task(task)
    @tasks << task
  end

  def success()
    @successful = true
  end

  def error(exception)
    @errors << exception
    @successful = false
  end

  def recover
    @successful = true
  end

  def reset
    @formatter = TestBuildFormatter.new(self)
    @started = false
    @finished = false
    @targets = []
    @tasks = []
    @successful = false
    @errors = []
    @prompt = ''
  end

  def output()
    return @formatter.output
  end

  def clear()
    @formatter.clear()
  end

  def error?
    return @errors.length > 0
  end

end

class TestBuildFormatter

  attr_reader :verbose
  attr_reader :output

  def initialize(listener)
    @listener = listener
    @verbose = false
    @output = ''
  end

  def print(text)
    @output << text
  end

  def puts(text)
    @output << text + "\n"
  end

  def clear()
    @output = ''
  end

end
