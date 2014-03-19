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

module Bee

  # Listener called when build events are triggered. Calls formatter to print
  # events on the console.
  class Listener

    # Formatter used by listener.
    attr_reader :formatter
    # Build start time.
    attr_reader :start_time
    # Build end time.
    attr_reader :end_time
    # Build duration.
    attr_reader :duration
    # Build success.
    attr_reader :successful
    # Last target met.
    attr_reader :last_target
    # Last task met.
    attr_reader :last_task
    # Raised exception during build
    attr_reader :exception

    # Constructor.
    # - formatter: the formatter to use to output on console.
    def initialize(formatter)
      @formatter = formatter
    end

    # Called when build is started.
    # - build: the build object.
    # - dry_run: tells if we are running in dry run.
    def start(build, dry_run)
      @start_time = Time.now
      @end_time = nil
      @duration = nil
      @successful = nil
      @last_target = nil
      @last_task = nil
      @formatter.print_build_started(build, dry_run)
    end

    # Called when build is finished.
    def stop()
      stop_chrono()
      @formatter.print_build_finished(@duration)
    end

    # Called when a target is met.
    # - target: the target object.
    def target(target)
      @last_target = target
      @last_task = nil
      @formatter.print_target(target)
    end

    # Called when a task is met.
    # - task: task source (shell, Ruby or task).
    def task(task)
      @last_task = task
      @formatter.print_task(task)
    end

    # Called when the build is a success.
    def success()
      @successful = true
      @exception = nil
    end

    # Called when an error was raised.
    # - exception: raised exception.
    def error(exception)
      @successful = false
      @exception = exception
      if exception.kind_of?(Bee::Util::BuildError)
        exception.target = @last_target if @last_target
        exception.task = @last_task if @last_task
      end
    end

    # Recover from a previous error (catching it for instance).
    def recover()
      @successful = true
      @exception = nil
    end

    private

    # Stop chronometer, write build end time and build duration.
    def stop_chrono()
      @end_time = Time.now
      @duration = @end_time - @start_time
      @duration = (@duration * 1000).round / 1000
    end

  end

end
