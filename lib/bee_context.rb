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
require 'bee_properties'

module Bee

  # Class for build context where properties live as local variables and where
  # all scripts (from context or in Ruby tasks) are evaluated.
  class Context

    include Bee::Util::BuildErrorMixin

    # The context binding
    attr_reader :context_binding

    # Constructor.
    # - properties: properties as a hash that gives expression for a given
    #   property.
    # - scripts: list of script files to run in context.
    def initialize(properties={}, scripts=[])
      @context_binding = get_binding
      @properties = properties
      @scripts = scripts
    end

    # Evaluate properties and scripts in the context. Should run while running
    # the build, not while loading it.
    def evaluate
      evaluate_default_properties
      evaluate_scripts
      evaluate_properties
    end

    # Return the list of properties (that is the list of local variables of
    # context) as an unsorted list of strings.
    def properties
      return eval('local_variables', @context_binding).map{|var| var.to_s}
    end

    # Set a given property in context.
    # - name: the property name as a string or symbol.
    # - value: the property value as an object.
    def set_property(name, value)
      begin
        eval("#{name} = #{value.inspect}", @context_binding)
      rescue Exception
        error "Error setting property '#{name} = #{value.inspect}': #{$!}"
      end
    end

    # Get a given property in context. Raises an error if the property was not
    # set.
    # - name: the property name.
    def get_property(name)
      begin
        eval("#{name}", @context_binding)
      rescue NameError
        error "Property '#{name}' was not set"
      rescue Exception
        error "Error getting property '#{name}': #{$!}"
      end
    end

    # Evaluate a script in context.
    # - source: source of the script to evaluate.
    def evaluate_script(source)
      eval(source, @context_binding)
    end

    # Process a given object, replacing properties references with their
    # string value, symbol with their raw value. Property references have
    # same form than variable references in ruby strings: '#{variable}'
    # will be replaced with variable string value.
    # - object: object to process.
    def evaluate_object(object)
      case object
      when NilClass
        # nil: return nil
        return nil
      when String
        # string: replace embedded Ruby expressions
        object = object.gsub(/#\{.+?\}/) do |match|
          expression = match[2..-2]
          begin
            value = eval(expression, @context_binding)
          rescue
            error "Error evaluating expression '#{expression}': #{$!}"
          end
          value
        end
        return object 
      when Symbol
        # symbol: return property object
        property = object.to_s
        begin
          value = eval("#{property}", @context_binding)
        rescue
          error "Property '#{property}' was not set"
        end
        return evaluate_object(value)
      when Array
        # array: evaluate each element
        return object.collect { |element| evaluate_object(element) }
      when Hash
        # hash: evaluate all keys and values
        evaluated = {}
        object.each_pair do |key, value| 
          evaluated[evaluate_object(key)] = evaluate_object(value)
        end
        return evaluated
      else
        return object
      end
    end

    private

    # Evaluate properties in context, except system properties.
    def evaluate_properties
      for name in (@properties.keys - Bee::Properties::SYSTEM_PROPERTIES)
        begin
          Thread.current[:stack] = []
          evaluate_property(name)
        ensure
          Thread.current[:stack] = nil
        end
      end
    end

    # Evaluate default properties in context.
    def evaluate_default_properties
      for name in Bee::Properties::SYSTEM_PROPERTIES
        begin
          Thread.current[:stack] = []
          evaluate_property(name)
        ensure
          Thread.current[:stack] = nil
        end
      end
    end

    # Evaluate a property with given name.
    # - name: the name of the property to evaluate.
    def evaluate_property(name)
      stack = Thread.current[:stack]
      error "Circular properties: #{stack.join(', ')}" if stack.include?(name)
      begin
        stack.push(name)
        value = evaluate_object(@properties[name])
        stack.pop
        set_property(name, value)
        return value
      rescue
        error "Error evaluating property '#{name}': #{$!}"
      end
    end

    # Evaluate scripts in the context.
    def evaluate_scripts
      for script in @scripts
        begin
          source = Bee::Util::get_file(script, @base)
          evaluate_script(source)
        rescue Exception
          error "Error loading context '#{script}': #{$!}"
        end
      end
    end

    # Catch missing properties as missing methods.
    # - name: the name of the missing property or method.
    def method_missing(name, *args, &block)
      if Thread.current[:stack]
        return evaluate_property(name)
      else
        raise NoMethodError.new("undefined method `#{name}'", name, args)
      end
    end

    # Get a binding as script context.
    def get_binding
      return binding
    end

  end

end
