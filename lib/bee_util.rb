# Copyright 2006-2012 Michel Casabianca <michel.casabianca@gmail.com>
#           2006 Avi Bryant
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
require 'net/http'
require 'bee_version_dependant'

module Bee
  
  module Util

    # Limit of number of HTTP redirections to follow.
    HTTP_REDIRECTIONS_LIMIT = 10
    # Default package name.
    DEFAULT_PACKAGE = 'default'    
    # Compact pattern for resource (':gem.file[version]')
    COMPACT_PATTERN  = /^:(.*?):(.*?)(\[(.*)\])?$/
    # Expanded pattern for resource ('ruby://gem:version/file')
    EXPANDED_PATTERN = /^ruby:\/\/(.*?)(:(.*?))?\/(.*)$/
    # Default terminal width
    DEFAULT_TERM_WIDTH = (RUBY_PLATFORM =~ /win32/ ? 79 : 80)

    # Get line length calling IOCTL. Return DEFAULT_TERM_WIDTH if call failed.
    def self.term_width
      begin
        tiocgwinsz = RUBY_PLATFORM =~ /darwin/ ? 0x40087468 : 0x5413
        string = [0, 0, 0, 0].pack('SSSS')
        if $stdin.ioctl(tiocgwinsz, string) >= 0 then
          rows, cols, xpixels, ypixels = string.unpack('SSSS')
          cols = DEFAULT_TERM_WIDTH if cols <= 0
          return cols
        else
          return DEFAULT_TERM_WIDTH
        end
      rescue
        return DEFAULT_TERM_WIDTH
      end
    end

    # Tells if we are running under Windows.
    def self.windows?
      return RUBY_PLATFORM =~ /(mswin|ming)/
    end

    # Parse packaged name and return package and name.
    # - packaged: packaged name (such as 'foo.bar').
    # Return: package ('foo') and name ('bar').
    def self.get_package_name(packaged)
      if packaged =~ /\./
        package, name = packaged.split('.')
      else
        package, name = DEFAULT_PACKAGE, packaged
      end
      return package, name
    end

    # Get a given file or URL. Manages HTTP redirections.
    # - location: file path, resource or URL of the file to get.
    # - base: base for relative files (defaults to nil, which is current dir).
    def self.get_file(location, base=nil)
      base = base || Dir.pwd
      abs = absolute_path(location, base)
      if abs =~ /^http:/
        # this is HTTP
        return fetch(abs)
      else
        # this is a file
        return File.read(abs)
      end  
    end

    private

    # Looks recursively up in file system for a file.
    # - file: file name to look for.
    # Return: found file or raises an exception if file was not found.
    def self.find(file)
      return file if File.exists?(file)
      raise "File not found" if File.identical?(File.dirname(file), '/')
      file = File.join('..', file)
      find(file)
    end

    # Tells is a given location is a URL (starting with 'http://').
    # - location: location to consider as a string.
    def self.url?(location)
      return false if not location.kind_of?(String)
      return location =~ /^http:\/\//
    end

    # Tells is a given location is a resource (starting with 'ruby://' or ':').
    # - location: location to consider as a string.
    def self.resource?(location)
      return false if not location.kind_of?(String)
      return location =~ /^ruby:\/\// || location =~ /^:/
    end

    # Tells if a given path is absolute.
    # - path: path to consider.
    def self.absolute_path?(path)
      if url?(path) or resource?(path)
        return true
      else
        if windows?
          return path =~ /^(([a-zA-Z]):)?\//
        else
          return path =~ /^\//
        end
      end
    end

    # Return absolute path for a given path and optional base:
    # - path: relative path to get absolute path for.
    # - base: optional base for path (defaults to current directory).
    def self.absolute_path(path, base=nil)
      path = File.expand_path(path) if path =~ /~.*/
      if absolute_path?(path)
        if resource?(path)
          path = resource_path(path)
        end
        return path
      else
        base = Dir.pwd if not base
        return File.join(base, path)
      end
    end

    # Get a given URL.
    # - url: URL to get.
    # - limit: redirectrion limit (defaults to HTTP_REDIRECTIONS_LIMIT).
    def self.fetch(url, limit=HTTP_REDIRECTIONS_LIMIT,
                   username=nil, password=nil)
      raise 'HTTP redirect too deep' if limit == 0
      response = Net::HTTP.get_response(URI.parse(url))
      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        fetch(response['location'], limit-1)
      when Net::HTTPUnauthorized
        uri = URI.parse(url)
        Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Get.new("#{uri.path}?#{uri.query}")
          request.basic_auth(username, password)
          response = http.request(request)
          return response.body
        end
      else
        response.error!
      end
    end

    # Return absolute path to a given resoure:
    # - resource: the resource (expanded patterns are like ':gem.file[version]'
    # and compact ones like 'ruby://gem:version/file').
    def self.resource_path(resource)
      # get gem, version and path from resource or interrupt build with an error
      case resource
      when COMPACT_PATTERN
        gem, version, path = $1, $4, $2
        gem = "bee_#{gem}" if gem != 'bee'
      when EXPANDED_PATTERN
        gem, version, path = $1, $3, $4
      else
        raise "'#{resource}' is not a valid resource"
      end
      # get gem descriptor
      if version
        if Gem::Specification.respond_to?(:find_by_name)
          begin
            gem_descriptor = Gem::Specification.find_by_name(gem, version)
          rescue Exception
            gem_descriptor = nil
          end
        else
          gem_descriptor = Gem.source_index.find_name(gem, version)[0]
        end
        raise "Gem '#{gem}' was not found in version '#{version}'" if
          not gem_descriptor
      else
        if Gem::Specification.respond_to?(:find_by_name)
          begin
            gem_descriptor = Gem::Specification::find_by_name(gem)
          rescue Exception
            gem_descriptor = nil
          end
        else
          gem_descriptor = Gem.source_index.find_name(gem)[0]
        end
        raise "Gem '#{gem}' was not found" if not gem_descriptor
      end
      # get resource path
      gem_path = gem_descriptor.full_gem_path
      file_path = File.join(gem_path, path)
      return file_path
    end

    # Find a given template and return associated file.
    # - template: template to look for (like 'foo.bar').
    # return: found associated file.
    def self.find_template(template)
      raise Bee::Util::BuildError.new("Invalid template name '#{template}'") if
        not template =~ /^([^.]+\.)?[^.]+$/
      package, egg = template.split('.')
      if not egg
        egg = package
        package = 'bee'
      end
      resource = ":#{package}:egg/#{egg}.yml"
      begin
        file = absolute_path(resource, Dir.pwd)
      rescue Exception
        raise BuildError.new("Template '#{template}' not found")
      end
      raise BuildError.new("Template '#{template}' not found") if
        not File.exists?(file)
      return file
    end

    # Search files for a given templates that might contain a joker (*).
    # - template: template to look for ('foo.bar' or 'foo.*' or '*.bar').
    # return: a hash associating template and corresponding file.
    def self.search_templates(template)
      raise Bee::Util::BuildError.
        new("Invalid template name '#{template}'") if
          not template =~ /^([^.]+\.)?[^.]+$/
      package, egg = template.split('.')
      if not egg
        egg = package
        package = 'bee'
      end
      egg = '*' if egg == '?'
      resource = ":#{package}:egg/#{egg}.yml"
      begin
        glob = absolute_path(resource, nil)
      rescue
        if egg == '*'
          raise BuildError.new("Template package '#{package}' not found")
        else
          raise BuildError.new("Template '#{template}' not found")
        end
      end
      files = Dir.glob(glob)
      hash = {}
      for file in files
        egg = file.match(/.*?([^\/]+)\.yml/)[1]
        name = "#{package}.#{egg}"
        hash[name] = file
      end
      return hash
    end

    # Aliases

    def self.gem_available?(gem)
      return Bee::VersionDependant::gem_available?(gem)
    end

    def self.find_gems(*patterns)
      return Bee::VersionDependant::find_gems(*patterns)
    end

    # Class that holds information about a given method.
    class MethodInfo
      
      attr_accessor :source, :comment, :defn, :params

      # Constructor taking file name and line number.
      # - file: file name of the method.
      # - lineno: line number of the method.
      def initialize(file, lineno)
        lines = file_cache(file)
        @source = match_tabs(lines, lineno, "def")
        @comment = preceding_comment(lines, lineno)
        @defn = lines[lineno].strip.gsub(/^def\W+(.*)/){$1}
        if @defn =~ /.*?\(.*?\)/
          @params = @defn.gsub(/.*?\((.*?)\)/){$1}.split(',').map{|p| p.strip}
        else
          @params = []
        end
      end
      
      private

      @@file_cache = {}
      
      def file_cache(file)
        unless lines = @@file_cache[file]
          @@file_cache[file] = lines = File.new(file).readlines
        end
        lines
      end	
      
      def match_tabs(lines, i, keyword)
        lines[i] =~ /(\W*)((#{keyword}(.*;\W*end)?)|(.*))/
        return $2 if $4 or $5
        tabs = $1
        result = ""
        lines[i..-1].each do |line|
          result << line.gsub(/^#{tabs}(.*)/) { $1}
          return result if $1 =~ /^end/
        end
      end
      
      def preceding_comment(lines, i)
        result = []
        i = i-1
        i = i-1 while lines[i] =~ /^\W*$/
        if lines[i] =~ /^=end/
          i = i-1
          until lines[i] =~ /^=begin/
            result.unshift lines[i]
            i = i-1
          end
        else
          while lines[i] =~ /^\W*#(.*)/
            result.unshift $1[1..-1]
            i = i-1
          end
        end
        result.join("\n")
      end
      
    end
    
    # This abstract class provides information about its methods.
    class MethodInfoBase
      
      @@minfo = {}

      # Return comment for a given method.
      # - method: the method name to get info for.
      def self.method_info(method)
        @@minfo[method.to_s]
      end
      
      private

      # Called when a method is added.
      # - method: added method.
      def self.method_added(method)
        super if defined? super
        last = caller[0]
        file, lineno = last.match(/(.+?):(\d+)/)[1, 2]
        @@minfo[method.to_s] = MethodInfo.new(file, lineno.to_i - 1)
      end
      
    end

    # Error raised on a user error. This error should be raised to interrupt
    # the build with a message on console but with no stack trace (that should
    # be displayed on an internal error only). Include BuildErrorMixin to get
    # a convenient way to raise such an error.
    class BuildError < RuntimeError
      
      # Last met target.
      attr_accessor :target
      # Last met task.
      attr_accessor :task

    end
    
    # Build error mixin provides error() function to raise a BuildError.
    # Use this function to interrupt the build on a user error (bad YAML
    # syntax, error running a task and so on). This will result in an
    # error message on the console, with no stack trace.
    module BuildErrorMixin
      
      # Convenient method to raise a BuildError.
      # - message: error message.
      def error(message)
        Kernel.raise BuildError.new(message)
      end
      
    end
    
    # Mixin that provides a way to check a hash entries using a description
    # that associates hash keys with a :mandatory or :optional symbol. Other
    # keys are not allowed.
    module HashCheckerMixin

      include BuildErrorMixin
      
      # Check that all mandatory keys are in the hash and all keys in the
      # hash are in description.
      # - hash: hash to check.
      # - description: hash keys description.
      def check_hash(hash, description)
        # check for mandatory keys
        for key in description.keys
          case description[key]
          when :mandatory
            error "Missing mandatory key '#{key}'" if not hash.has_key?(key)
          when :optional
          else
            error "Unknown symbol '#{description[key]}'"
          end
        end
        # look for unknown keys in hash
        for key in hash.keys
          error "Unknown key '#{key}'" if not description.keys.member?(key)
        end
      end
      
    end

  end
  
end
