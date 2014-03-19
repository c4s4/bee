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
require 'syck'
require 'yaml'
require 'bee_util'
require 'bee_context'
require 'bee_properties'
require 'bee_target'
require 'bee_targets'
require 'bee_task_packagemanager'

module Bee
  
  # Class for a build, built from an object resulting from YAML build file parsing.
  class Build
    
    include Bee::Util::BuildErrorMixin
    include Bee::Util::HashCheckerMixin

    # Build key.
    KEY = 'build'
    # Build entry description.
    DESCRIPTION = {
      'build'       => :mandatory, 
      'default'     => :optional, 
      'description' => :optional,
      'context'     => :optional,
      'extends'     => :optional,
      'abstract'    => :optional,
      'alias'       => :optional
    }

    # Build file.
    attr_reader :file
    # Base directory, that is directory where lives the build file.
    attr_reader :base
    # Current directory, where was started the script.
    attr_reader :here
    # Build name.
    attr_reader :name
    # Parent build.
    attr_reader :extends
    # Abstractness.
    attr_reader :abstract
    # Build description.
    attr_reader :description
    # Build properties.
    attr_reader :properties
    # Hash for targets, indexed by target name.
    attr_reader :targets
    # Context for Ruby scripts and properties.
    attr_reader :context
    # Package manager, for task invocation.
    attr_reader :package_manager
    # Build listener, responsible for displaying build status.
    attr_reader :listener
    
    # Load a build from a YAML build file.
    # - file: YAML build file or URL.
    # - recursive: tells if we look for build file recursively (defaults to
    #   nil).
    # - properties: a hash of additional properties passed on command line.
    def self.load(file, recursive=nil, properties={})
      raise "Can't use recursive URL" if recursive and Bee::Util::url?(file)
      if recursive
        begin
          file = Bee::Util::find(file)
        rescue
          raise Bee::Util::BuildError.new("Build file '#{file}' " +
                                          "not found recursively")
        end
      end
      begin
        yaml = Bee::Util::get_file(file)
        object = YAML::load(yaml)
      rescue
        raise Bee::Util::BuildError.
           new("Error loading build file '#{file}': #{$!}")
      end
      return Build.new(object, file, properties)
    end
    
    # Constructor:
    # - object: object tree resulting from YAML build file parsing.
    # - file: build file (nil if none).
    # - properties: a hash of additional properties passed on command line.
    # - here: current directory.
    def initialize(object, file, properties={}, here=Dir.pwd)
      @file = file
      @base = get_base(@file)
      @here = here
      @properties = Bee::Properties.new
      @scripts = []
      @targets = Targets.new(self)
      parse(object)
      @properties.overwrite(properties)
      @properties.defaults({:base => @base, :here => @here})
      @context = Context.new(@properties.expressions, @scripts)
      @package_manager = Bee::Task::PackageManager.new(self)
    end

    # Run build. Raise a BuildError exception on build error if no listener
    # was given to be notified of the build failure:
    # - targets: list of targets to run.
    # - listener: listener for the build.
    def run(targets, listener=nil, dry=false)
      @listener = listener
      working_directory = Dir.getwd
      @listener.start(self, dry) if @listener
      begin
        error "Abstract build file, must be extended to run" if @abstract
        if not Bee::Util::url?(@base)
          Dir.chdir(@base)
        end
        @context.evaluate
        @targets.run(targets, dry)
        @listener.success() if @listener
      rescue Bee::Util::BuildError
        @listener.error($!) if @listener
        raise $!
      ensure
        @listener.stop() if @listener
        Dir.chdir(working_directory)
        remove_instance_variable(:@listener)
      end
    end
    
    private

    # Parse entries in build object.
    # - object: object tree resulting from YAML build file parsing.
    def parse(object)
      error "Build must be a list" unless object.kind_of?(Array)
      first = true
      for entry in object
        if entry.key?(Build::KEY)
          parse_build(entry)
          error "Build info entry must be first one in build file" if not first
          first = false
        elsif entry.key?(Properties::KEY)
          properties = entry[Properties::KEY]
          # if properties is a string, this is a YAML file to load as a Hash
          if properties.kind_of?(String)
            filename = properties
            begin
              properties = YAML::load(Bee::Util::get_file(filename, @base))
              @properties.write(properties)
            rescue Exception
              error "Error loading properties file '#{filename}': #{$!}"
            end
          else
            @properties.write(properties)
          end
          first = false
        elsif entry.key?(Target::KEY)
          @targets.add(entry)
          first = false
        else
          error "Unknown entry:\n#{YAML::dump(entry)}"
        end
      end
      # manage extended builds
      if @extends
        for parent in @extends
          @properties.extend(parent.properties.expressions)
          @targets.extend(parent.targets)
        end
      end
    end
    
    # Parse a build entry.
    # - entry: the build entry to parse.
    def parse_build(entry)
      begin
        check_hash(entry, Build::DESCRIPTION)
      rescue
        error "Error parsing build info entry: #{$!}"
      end
      error "Duplicate build info" if @name
      @name = entry['build']
      # check that 'default' entry is a string or an array
      error "'default' entry of the 'build' block must be a string or an array" if
        entry['default'] and (!entry['default'].kind_of?(String) and
                              !entry['default'].kind_of?(Array))
      if entry['default']
        @targets.default = Array(entry['default'])
        @targets.default_set = true
      end
      # check that 'alias' entry is a hash
      error "'alias' entry of the 'build' block must be a hash" if
        entry['alias'] and !entry['alias'].kind_of?(Hash)
      if entry['alias']
        @targets.alias = entry['alias']
        @targets.alias_set = @targets.alias.keys()
      else
        @targets.alias_set = []
      end
      @description = entry['description']
      @abstract = entry['abstract']
      # load parents build if any
      parents = Array(entry['extends'])
      if parents.length > 0
        @extends = []
        for extended in parents
          absolute_path = Bee::Util::absolute_path(extended, @base)
          begin
            @extends << Bee::Build::load(absolute_path)
          rescue Exception
            error "Error loading parent build file '#{extended}': #{$!}"
          end
        end
      end
      # check that there are no property and target collisions in parents
      if @extends
        properties = []
        collisions = []
        for parent in @extends
          parent_properties = parent.properties.expressions.keys
          collisions += properties & parent_properties
          properties += parent_properties
        end
        collisions = collisions - Bee::Properties::SYSTEM_PROPERTIES
        collisions = collisions.uniq.map { |e| e.to_s }.sort
        if collisions.length > 0
          error "Properties in parents are colliding: #{collisions.join(', ')}"
        end
        targets = []
        collisions = []
        for parent in @extends
          parent_targets = parent.targets.hash.keys
          collisions += targets & parent_targets
          targets += parent_targets
        end
        collisions = collisions.uniq.map { |e| e.to_s }.sort
        if collisions.length > 0
          error "Targets in parents are colliding: #{collisions.join(', ')}"
        end
      end
      # load context files if any
      context = entry['context']
      @scripts = Array(context) if context
    end
    
    # Get base for a given file.
    # - file: build file.
    def get_base(file)
      if file
        if Bee::Util::url?(file)
          return File.dirname(file)
        else
          return File.expand_path(File.dirname(file))
        end
      else
        return File.expand_path(Dir.pwd)
      end
    end

  end

  # Return Bee version. Try to load bee_version file or return UNKNOWN.
  def version
    begin
      require 'bee_version'
      return Bee::VERSION
    rescue Exception
      return 'UNKNOWN'
    end
  end

  module_function :version
  
end
