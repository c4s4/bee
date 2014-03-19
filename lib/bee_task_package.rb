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
require 'bee_build'
require 'bee_util'

module Bee
  
  module Task

    # Base class for task package. Provides methods to print output using
    # the build formatter and a method to check task parameters. Furthermore,
    # this base class extends MethodInfoBase which provides methods
    # comments, for autodocumentation purpose.
    class Package < Bee::Util::MethodInfoBase
      
      include Bee::Util::BuildErrorMixin

      # Verbosity indicator
      attr_reader :verbose
      
      # Constructor.
      # - build: the build we are running.
      def initialize(build)
        @build = build
        if @build and @build.listener
          @verbose = @build.listener.formatter.verbose
        else
          @verbose = false
        end
      end

      protected

      # Check task parameters. Raise a RuntimeError with explanation message
      # if a mandatory parameter is missing or an unknown parameter was found.
      # - params: task parameters as a Hash.
      # - description: parameters description as a Hash with following keys:
      #   :mandatory telling if the parameter is mandatory (true or false),
      #   :type which is the class name of the parameter and
      #   :default for default value.
      def check_parameters(params, description)
        task = caller[0].match(/`(.*)'/)[1]
        error "'#{task}' parameters must be a hash" unless params.kind_of?(Hash)
        for param in description.keys
          error "#{task} '#{param}' parameter is mandatory" unless
            params[param.to_s] or description[param][:mandatory] == false
          if params[param.to_s] != nil
            case description[param][:type]
            when :string
              error "#{task} '#{param}' parameter must be a string" unless
                params[param.to_s].kind_of?(String)
            when :integer
              error "#{task} '#{param}' parameter must be an integer" unless
                params[param.to_s].kind_of?(Integer)
            when :float
              error "#{task} '#{param}' parameter must be a float" unless
                params[param.to_s].kind_of?(Float)
            when :number
              error "#{task} '#{param}' parameter must be a number" unless
                params[param.to_s].kind_of?(Numeric)
            when :boolean
              error "#{task} '#{param}' parameter must be a boolean" unless
                params[param.to_s] == true or params[param.to_s] == false
            when :array
              error "#{task} '#{param}' parameter must be an array" unless
                params[param.to_s].kind_of?(Array)
            when :string_or_array
              error "#{task} '#{param}' parameter must be a string or an array" unless
                params[param.to_s].kind_of?(String) or params[param.to_s].kind_of?(Array)
              params[param.to_s] = Array(params[param.to_s])
            when :string_or_integer
              error "#{task} '#{param}' parameter must be a string or an integer" unless
                params[param.to_s].kind_of?(String) or params[param.to_s].kind_of?(Integer)
            when :hash
              error "#{task} '#{param}' parameter must be a hash" unless
                params[param.to_s].kind_of?(Hash)
            when :hash_or_array
              error "#{task} '#{param}' parameter must be a hash or list of hashes" unless
                params[param.to_s].kind_of?(Hash) or params[param.to_s].kind_of?(Array)
              if params[param.to_s].kind_of?(Hash)
                params[param.to_s] = [params[param.to_s]]
              elsif !params[param.to_s].kind_of?(Array)
                error "#{task} '#{param}' parameter must be a hash or a list of hashes"
              end
            else
              error "Unknown parameter type '#{description[param][:type]}'"
            end
            params[param.to_sym] = params[param.to_s]
          else
            if description[param][:default]
              params[param.to_sym] = description[param][:default]
              params[param.to_s] = description[param][:default]
            end
          end
        end
        for param in params.keys
          error "Unknown parameter '#{param}'" if 
            not (description.key?(param) or description.key?(param.to_sym))
        end
      end
      
      # Utility method to find and filter files.
      # - root: root directory for files to search.
      # - includes: list of globs for files to include in search.
      # - excludes: list of globs for files to exclude from search.
      # - dotmatch: tells if joker matches dot files.
      # Return: the list of found files (no directories included).
      def filter_files(root, includes, excludes, dotmatch=true)
        error "includes must be a glob or a list of globs" unless
          !includes or includes.kind_of?(String) or includes.kind_of?(Array)
        error "excludes must be a glob or a list of globs" unless
          !excludes or excludes.kind_of?(String) or excludes.kind_of?(Array)
        error "root must be an existing directory" unless
          !root or File.exists?(root)
        current_dir = Dir.pwd
        begin
          if dotmatch
            options = File::FNM_PATHNAME | File::FNM_DOTMATCH
          else
            options = File::FNM_PATHNAME
          end
          Dir.chdir(root) if root
          included = []
          includes = '**/*' if not includes
          includes = Array(includes)
          for include in includes
            error "includes must be a glob or a list of globs" unless
              include.kind_of?(String)
            # should expand directories ?
            # include = "#{include}/**/*" if File.directory?(include)
            entries = Dir.glob(include, options)
            included += entries if entries
          end
          included.uniq!
          if excludes
            included.reject! do |file|
              rejected = false
              for exclude in excludes
                if File.fnmatch?(exclude, file, options)
                  rejected = true
                  break
                end
              end
              rejected
            end
          end
          included.reject! { |file| File.directory?(file) }
          return included
        ensure
          Dir.chdir(current_dir)
        end
      end

      # Copy a list of files to a given diretory:
      # - root: root directory of source files.
      # - files: a list of files to copy relative to root.
      # - dest: destination directory.
      # - flatten: tells if a flat copy is made.
      def copy_files(root, files, dest, flatten)
        puts "Copying #{files.length} file(s) to '#{dest}'"
        for file in files
          from_file = File.join(root, file)
          if flatten
            to_file = File.join(dest, File.basename(file))
          else
            to_file = File.join(dest, file)
          end
          to_dir    = File.dirname(to_file)
          FileUtils.makedirs(to_dir) if not File.exists?(to_dir)
          FileUtils.cp(from_file, to_file)
        end
      end

      # Print text on the console.
      # - text: text to print.
      def print(text)
        if @build and @build.listener
          @build.listener.formatter.print(text)
        else
          Kernel.print(text)
        end
      end
      
      # Puts text on the console.
      # - text: text to puts.
      def puts(text)
        if @build and @build.listener
          @build.listener.formatter.puts(text)
        else
          Kernel.puts(text)
        end
      end

    end
    
  end
  
end
