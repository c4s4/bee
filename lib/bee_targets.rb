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
require 'bee_target'

module Bee

  # Class to manage targets in a build.
  class Targets

    include Bee::Util::BuildErrorMixin

    # The build.
    attr_reader :build
    # Targets hash by name.
    attr_reader :hash
    # List of targets that already ran.
    attr_reader :already_run
    # Default target.
    attr_accessor :default
    # Tells if defautl target was set in build file
    attr_accessor :default_set
    # Alias for targets
    attr_accessor :alias
    # Tells if alias was set in build file
    attr_accessor :alias_set

    # Constructor.
    # - build: build object.
    def initialize(build)
      @build = build
      @hash = {}
      @already_run = []
    end

    # Add a new target.
    # - object: object tree resulting from YAML build file parsing.
    def add(object)
      begin
        target = Target.new(object, self)
      rescue
        error "Error parsing target '#{object[Bee::Target::KEY]}': #{$!}"
      end
      error "Duplicate target definition: '#{target.name}'" if
        @hash.has_key?(target.name)
      @hash[target.name] = [target]
      # record first target for default
    end

    # Extend parent targets.
    # - parent: parent targets.
    def extend(parent)
      # set appropriate targets for targets of parent
      for targets in parent.hash.values
        for target in targets
          target.targets = self
        end
      end
      # insert parent targets before current ones
      for name in parent.hash.keys
        if @hash[name]
          @hash[name] = parent.hash[name] + @hash[name]
          # clean dependencies for redefined targets
          for target in parent.hash[name]
            target.depends.clear
          end
          # copy documentation of parent if target not documented
          if not @hash[name].last.description
            description = nil
            for target in parent.hash[name]
              description = target.description || description
            end
            @hash[name].last.description = description
          end
        else
          @hash[name] = parent.hash[name]
        end
      end
      # manage default target
      if parent.default and !@default_set
        @default = [] if !@default
        @default += parent.default
      end
      @default = @default || parent.default
      # manage aliases
      @alias = {} if !@alias
      if parent.alias
        for key in parent.alias.keys
          if !@alias_set.include?(key)
            if @alias.has_key?(key)
              @alias[key] = Array(@alias[key]) + Array(parent.alias[key])
            else
              @alias[key] = Array(parent.alias[key])
            end
          end
        end
      end
    end

    # Run a given target.
    # - target: the target to run.
    # - dry: tells if we run in dry mode. Defaults to false.
    def run_target(target, dry=false)
      error "Target '#{target}' not found" if not @hash[target]
      if not @already_run.include?(target)
        @already_run << target
        @hash[target].last.run(dry)
      end
    end

    # Run targets.
    # - targets: list of target names to run.
    def run(targets, dry)
      targets = [] if targets == ''
      targets = targets || []
      targets = Array(targets)
      if targets.length == 0
        if @default
          targets = @default
        else
          error "No default target given"
        end
      end
      aliased_targets = []
      for target in targets
        if @alias and @alias.has_key?(target)
          aliased_targets += Array(@alias[target])
        else
          aliased_targets << target
        end
      end
      for target in aliased_targets
        run_target(target, dry)
        @already_run.clear
      end
    end

    # Call super target.
    # - target: target to call super onto.
    def call_super(target, dry=false)
      index = @hash[target.name].index(target)
      error "No super target to call for '#{target.name}'" if index == 0
      index -= 1
      @hash[target.name][index].run(dry)
    end

    # Tells if a given target is last in hierarchy.
    # - target: given target.
    def is_last(target)
      index = @hash[target.name].index(target)
      last = @hash[target.name].size - 1
      return index == last
    end

    # Return targets description as a hash of descriptions indexed by
    # target name. Dependencies are added after target description.
    def description
      description = {}
      for name in @hash.keys
        text = @hash[name].last.description
        if @hash[name].last.depends and @hash[name].last.depends.length > 0
          depends = ' [' + @hash[name].last.depends.join(', ') + ']'
        else
          depends = nil
        end
        description[name] = (text ? text : '') + (depends ? depends : '')
      end
      return description
    end

  end

end
