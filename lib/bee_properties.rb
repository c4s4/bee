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
  
  # Class to manage properties.
  class Properties

    include Bee::Util::BuildErrorMixin

    # System properties
    SYSTEM_PROPERTIES = [:base, :here]

    # Key for properties entry.
    KEY = 'properties'

    # Properties expressions
    attr_reader :expressions

    # Constructor.
    # - properties: properties as a hash.
    def initialize(properties={})
      @expressions = {}
      check_properties(properties)
      set_properties(properties, false)
    end

    # Write new properties with passed expressions.
    # - properties: properties as a hash.
    def write(properties)
      check_properties(properties)
      set_properties(properties, false)
    end

    # Overwrite properties with those passed.
    # - properties: properties as a hash.
    def overwrite(properties)
      check_properties(properties)
      set_properties(properties, true)
    end

    # Set default properties: if they are already defined, will raise an error.
    # - properties: default properties as a hash.
    def defaults(properties)
      set_properties(properties, true)
    end

    # Extend with properties of parent build.
    # - properties: properties of parent build as a hash.
    def extend(properties)
      check_properties_type(properties)
      for name in properties.keys
        @expressions[name] = properties[name] if !@expressions.include?(name)
      end
    end

    private

    # Check that properties are a hash and raise a BuildError if not.
    # - properties: properties to check as a hash.
    def check_properties_type(properties)
      error "Properties must be a hash" if not properties.kind_of?(Hash)
    end

    # Check properties for system ones:
    # - properties: properties expressions as a hash.
    def check_properties(properties)
      check_properties_type(properties)
      names = SYSTEM_PROPERTIES & properties.keys.map {|k| k.to_sym}
      if names.length > 1
        error "#{names.join(' and ')} are reserved property names"
      elsif names.length > 0
        error "#{names[0]} is a reserved property name"
      end
    end

    # Set properties.
    # - properties: properties as a hash.
    # - overwrite: tells if we can overwrite existing properties.
    def set_properties(properties, overwrite)
      check_properties_type(properties)
      for name in properties.keys
        expression = properties[name]
        set_property(name, expression, overwrite)
      end
    end

    # Set a given named property with an expression.
    # - name: property name (as a string or symbol).
    # - expression: property expression as a string.
    # - overwrite: tells if we can overwrite existing properties.
    def set_property(name, expression, overwrite)
      return if expression == nil
      name = name.to_sym
      error "Duplicate property definition: '#{name}'" if 
        not overwrite and @expressions.has_key?(name)
      @expressions[name] = expression
    end

  end

end
