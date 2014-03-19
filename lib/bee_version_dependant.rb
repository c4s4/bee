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

module Bee

  module VersionDependant

    # Convert a string to a version number (array of integers). Thus will turn
    # '1.2.3' to [1, 2, 3].
    def self.to_version(string)
      return string.split('.').map{|s| s.to_i}
    end

    # Compares two versions.
    # Returns:
    # - < 0 if first is lower than second.
    # - > 0 if first is greater than second.
    # - = 0 if first is equal to second.
    def self.compare_versions(v1, v2)
      v1 = to_version(v1) if v1.kind_of?(String)
      v2 = to_version(v2) if v2.kind_of?(String)
      return (v1 <=> v2)
    end

    # Get Ruby version as an Array.
    def self.ruby_version()
      return to_version(RUBY_VERSION)
    end

    # Get Gems version.
    def self.gems_version()
      return Gem::RubyGemsVersion
    end

    # Tells if ruby version is greater than a given string version.
    def self.ruby_greater_than(version)
      return compare_versions(ruby_version, to_version(version)) > 0
    end

    # Tells if ruby version is lower than a given string version.
    def self.ruby_lower_than(version)
      return compare_versions(ruby_version, to_version(version)) < 0
    end

    # Tells if ruby version equals a given string version.
    def self.ruby_equals_to(version)
      return compare_versions(ruby_version, to_version(version)) == 0
    end

    # Tells if a given gem is available.
    def self.gem_available?(gem)
      if compare_versions(gems_version, [1, 3, 0]) < 0
        begin
          Gem::activate(gem, false)
          return true
        rescue LoadError
          return false
        end
      elsif compare_versions(gems_version, [1, 8, 0]) < 0
        return Gem::available?(gem)
      else
        begin
          Gem::Specification::find_by_name(gem)
          return true
        rescue LoadError
          return false
        end
      end
    end

    # Find gems with name matching a given pattern. Returns the list of gem
    # specifications.
    def self.find_gems(*patterns)
      gems = []
      if compare_versions(gems_version, [1, 8, 0]) < 0
        index = Gem::SourceIndex.from_installed_gems()
        for pattern in patterns
          gems += index.find_name(pattern)
        end
      else
        for pattern in patterns
          Gem::Specification::each do |spec|
            gems << spec if spec.name =~ pattern
          end
        end
      end
      return gems.uniq
    end

  end

end

# patch test/unit to disable autorun for Ruby 1.9.2 or 1.9.1
if Bee::VersionDependant::ruby_equals_to('1.9.2') or Bee::VersionDependant::ruby_equals_to('1.9.1')

  require 'minitest/unit'

  module MiniTest

    class Unit
      def self.autorun
      end
    end

  end

end

# patch test/unit to disable autorun for Ruby 1.9.3
if Bee::VersionDependant::ruby_equals_to('1.9.3')

  require 'test/unit'

  class Test::Unit::Runner
    @@stop_auto_run = true
  end

end
