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
require 'bee_util'

module Bee
  
  # Class for a target. It is built from the YAML build file and manages a
  # target, in particular, tasks execution.
  class Target
    
    include Bee::Util::BuildErrorMixin
    include Bee::Util::HashCheckerMixin

    # Target key.
    KEY = 'target'
    # Target entry description.
    DESCRIPTION = {
      'target'      => :mandatory,
      'depends'     => :optional,
      'description' => :optional,
      'script'      => :optional}

    # Targets for build.
    attr_accessor :targets
    # Name of the target.
    attr_reader :name
    # Target dependencies.
    attr_accessor :depends
    # Target description.
    attr_accessor :description
    # Script that run in the target.
    attr_reader :script
    
    # Constructor.
    # - object: object for target, resulting from YAML parsing.
    # - targets: build targets.
    def initialize(object, targets)
      check_hash(object, Target::DESCRIPTION)
      @targets = targets
      @name = object[Target::KEY]
      error "Target name cannot be 'null'" if @name == nil
      @depends = Array(object['depends']||[])
      @description = object['description']
      @script = Array(object['script']||[])
    end
    
    # Run target.
    # - dry: tells if we run in dry mode. Defaults to false.
    def run(dry=false)
      current_dir = Dir.pwd
      begin
        for depend in @depends
          @targets.run_target(depend, dry)
        end
        @targets.build.listener.target(self) if 
          @targets.build.listener and @targets.is_last(self)
        run_block(@script, dry)
      ensure
        Dir.chdir(current_dir)
      end
    end
    
    private
    
    # Run a task.
    # - task: the task to run.
    # - dry: whether to just print.
    def run_task(task, dry=false)
      @targets.build.listener.task(task) if @targets.build.listener
      case task
      when String
        # shell script
        run_shell(task, dry)
      when Hash
        if task.keys.length > 1
          # construct
          run_construct(task, dry)
        else
          if task.key?('rb')
            # ruby script
            script = task['rb']
            run_ruby(script, dry)
          elsif task.key?('sh')
            # shell script
            script = task['sh']
            run_shell(script, dry)
          elsif task.key?('super')
            # call super target
            targets.call_super(self, dry)
          else
            # bee task
            run_bee_task(task, dry)
          end
        end
      else
        raise "Task must be a string or a hash"
      end
    end
    
    # Run a given shell script.
    # - script: the scrip to run.
    def run_shell(script, dry=false)
      @listener.task(script) if @listener
      return if dry
      evaluated_script = @targets.build.context.evaluate_object(script)
      if evaluated_script != ''
        system(evaluated_script)
        error "Script exited with value #{$?}" if $? != 0
      end
    end
    
    # Run a given shell script.
    # - script: the scrip to run.
    # - dry: tells if we run in dry mode.
    def run_ruby(script, dry=false)
      @listener.task(script) if @listener
      return if dry
      begin
        @targets.build.context.evaluate_script(script)
      rescue Interrupt
        raise $!
      rescue Exception
        error "Error running Ruby script: #{$!}"
      end
    end
    
    # Run a given bee task.
    # - task: task to run as a Hash.
    def run_bee_task(task, dry=false)
      @listener.task(task) if @listener
      return if dry
      @targets.build.package_manager.run_task(task)
    end

    # Run a given construct.
    # - construct: construct to run as a Hash.
    # - dry: tells if we are running in dry mode. Defaults to false.
    def run_construct(construct, dry=false)
      @listener.task(construct) if @listener
      return if dry
      # if construct
      if construct.keys.include?('if')
        construct_if(construct, dry)
      # while construct
      elsif construct.keys.include?('while')
        construct_while(construct, dry)
      # for construct
      elsif construct.keys.include?('for')
        construct_for(construct, dry)
      # try construct
      elsif construct.keys.include?('try')
        construct_try(construct, dry)
      else
        error "Unknown construct '#{construct.keys.join('-')}'"
      end
    end

    # Run if construct.
    # - task: the construct as a hash.
    # - dry: tells if we run in dry mode.
    def construct_if(task, dry)
      # test entries
      error "If-then-else construct must include 'then' entry" if
        not task.keys.include?('then')
      unknown_keys = task.keys - ['if', 'then', 'else']
      error "If-then-else construct may only include 'if', 'then' and 'else' entries" if
        unknown_keys.length > 0
      error "If entry in if-then-else construct must be a string, a symbol or a boolean" if
        not task['if'].kind_of?(String) and
        not task['if'].kind_of?(Symbol) and
        not (task['if'].kind_of?(TrueClass) or task['if'].kind_of?(FalseClass))
      error "Then entry in if-then-else construct must be a list" if
        not task['then'].kind_of?(Array)
      error "Else entry in if-then-else construct must be a list" if
        task['else'] and not task['else'].kind_of?(Array)
      # evaluate condition in the build context
      if evaluate(task['if'])
        run_block(task['then'], dry)
      else
        run_block(task['else'], dry) if task['else']
      end
    end

    # Run while construct.
    # - task: the construct as a hash.
    # - dry: tells if we run in dry mode.
    def construct_while(task, dry)
      # test entries
      error "While-do construct must include 'do' entry" if
        not task.keys.include?('do')
      unknown_keys = task.keys - ['while', 'do']
      error "While-do construct may only include 'while' and 'do' entries" if
        unknown_keys.length > 0
      error "While entry in while-do construct must be a string" if
        not task['while'].kind_of?(String)
      error "Do entry in while-do construct must be a list" if
        not task['do'].kind_of?(Array)
      # evaluate condition in the build context
      while evaluate(task['while'])
        run_block(task['do'], dry)
      end
    end

    # Run for construct.
    # - task: the construct as a hash.
    # - dry: tells if we run in dry mode.
    def construct_for(task, dry)
      # test entries
      error "For-in-do construct must include 'in' and 'do' entries" if
        not task.keys.include?('in') or
        not task.keys.include?('do')
      unknown_keys = task.keys - ['for', 'in', 'do']
      error "For-in-do construct may only include 'for', 'in' and 'do' entries" if
        unknown_keys.length > 0
      error "For entry in for-in-do construct must be a string" if
        not task['for'].kind_of?(String)
      error "In entry in for-in-do construct must be a list, a string or a symbol" if
        not task['in'].kind_of?(Enumerable) and
        not task['in'].kind_of?(String) and
        not task['in'].kind_of?(Symbol)
      error "Do entry in for-in-do construct must be a list" if
        not task['do'].kind_of?(Array)
      # iterate over list
      if task['in'].kind_of?(String) or task['in'].kind_of?(Symbol)
        enumerable = evaluate(task['in'])
        error "In entry in for-in-do construct must result in an enumerable" if
          not enumerable.kind_of?(Enumerable)
      else
        enumerable = task['in']
      end
      for element in enumerable
        begin
          @targets.build.context.set_property(task['for'], element)
        rescue
          error "Error setting property '#{task['for']}'"
        end
        run_block(task['do'], dry)
      end
    end

    # Run try-catch construct.
    # - task: the construct as a hash.
    # - dry: tells if we run in dry mode.
    def construct_try(task, dry)
      # test entries
      error "Try-catch construct must include 'catch' entry" if
        not task.keys.include?('catch')
      unknown_keys = task.keys - ['try', 'catch']
      error "Try-catch construct may only include 'try' and 'catch' entries" if
        unknown_keys.length > 0
      error "Try entry in try-catch construct must be a list" if
        not task['try'].kind_of?(Array)
      error "Catch entry in try-catch construct must be a list" if
        task['catch'] and not task['catch'].kind_of?(Array)
      # try and catch errors
      begin
        run_block(task['try'], dry)
      rescue
        @targets.build.listener.recover if @targets.build.listener
        run_block(task['catch'], dry) if task['catch']

      end
    end

    # Run a block, that is a list of tasks.
    # - block: the block to run as a list of tasks.
    # - dry: tells if we run in dry mode.
    def run_block(block, dry)
      for task in block
        run_task(task, dry)
      end   
    end

    # Evaluate a given expression and raise a BuildError if an error happens.
    def evaluate(expression)
      begin
        if expression.kind_of?(String)
          return @targets.build.context.evaluate_script(expression)
        elsif (expression.kind_of?(TrueClass) or expression.kind_of?(FalseClass))
          return expression
        else
          return @targets.build.context.evaluate_object(expression)
        end
      rescue
        error "Error evaluating expression: #{$!}"
      end
    end

  end

end
