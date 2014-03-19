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

  module Console

    # Class to manage a style for console output.
    class Style

      include Bee::Util::BuildErrorMixin

      # style attributes
      attr_reader :line_character
      attr_reader :line_length
      attr_reader :target_style
      attr_reader :target_foreground
      attr_reader :target_background
      attr_reader :task_style
      attr_reader :task_foreground
      attr_reader :task_background
      attr_reader :success_style
      attr_reader :success_foreground
      attr_reader :success_background
      attr_reader :error_style
      attr_reader :error_foreground
      attr_reader :error_background

      # List of style types
      TYPES = [:target, :task, :success, :error]

      # List of colors.
      COLORS = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]

      # Foreground color codes.
      FOREGROUND_COLOR_CODES = {
        :black   => 30,
        :red     => 31,
        :green   => 32,
        :yellow  => 33,
        :blue    => 34,
        :magenta => 35,
        :cyan    => 36,
        :white   => 37
      }

      # Background color codes.
      BACKGROUND_COLOR_CODES = {
        :black   => 40,
        :red     => 41,
        :green   => 42,
        :yellow  => 43,
        :blue    => 44,
        :magenta => 45,
        :cyan    => 46,
        :white   => 47
      }

      # List of styles.
      STYLES = [:reset, :bright, :dim, :underscore, :blink, :reverse, :hidden]

      # Style codes.
      STYLE_CODES = {
        :reset      => 0,
        :bright     => 1,
        :dim        => 2,
        :underscore => 4,
        :blink      => 5,
        :reverse    => 7,
        :hidden     => 8
      }

      # Default style (supposed to work on any configuration).
      DEFAULT_STYLE = {
        :line_character => '-'
      }

      # Color style (supposed to work on color terminals).
      COLOR_STYLE = {
        :line_character     => '-',
        :target_foreground  => :yellow,
        :task_foreground    => :blue,
        :success_style      => :bright,
        :success_foreground => :green,
        :error_style        => :bright,
        :error_foreground   => :red
      }

      # Short style keys for command line
      SHORT_STYLE_KEYS = {
        'lc' => 'line_character',
        'll' => 'line_length',
        'ts' => 'target_style',
        'tf' => 'target_foreground',
        'tb' => 'target_background',
        'ks' => 'task_style',
        'kf' => 'task_foreground',
        'kb' => 'task_background',
        'ss' => 'success_style',
        'sf' => 'success_foreground',
        'sb' => 'success_background',
        'es' => 'error_style',
        'ef' => 'error_foreground',
        'eb' => 'error_background'
      }

      # Build the style from command line arguments:
      # - style: the style as a hash or a string (as passed on command line).
      #   Defaults to nil.
      # - color: tells if we use color style. Defaults to nil.
      def initialize(style=nil, color=nil)
        @line_character = nil
        @line_length = nil
        @target_style = nil
        @target_foreground = nil
        @target_background = nil
        @task_style = nil
        @task_foreground = nil
        @task_background = nil
        @success_style = nil
        @success_foreground = nil
        @success_background = nil
        @error_style = nil
        @error_foreground = nil
        @error_background = nil
        apply(color ? COLOR_STYLE : DEFAULT_STYLE)
        apply(style)
      end

      # Apply style to a string:
      # - string: the string to apply style to.
      # - type: the type of style to apply (one of :target, :task, :success or
      #   :error).
      def style(string, type)
        raise "Type '#{type}' unknown: must be one of " + TYPES.map{|e| ":#{e}"}.join(', ') if
          not TYPES.include?(type)
        style = eval("@#{type}_style")
        foreground = eval("@#{type}_foreground")
        background = eval("@#{type}_background")
        # if no style nor colors, return raw string
        return string if not foreground and not background and not style
        # insert style and colors in string
        colorized = "\e["
        colorized << "#{STYLE_CODES[style]};" if style
        colorized << "#{FOREGROUND_COLOR_CODES[foreground]};" if foreground
        colorized << "#{BACKGROUND_COLOR_CODES[background]};" if background
        colorized = colorized[0..-2]
        colorized << "m#{string}\e[#{STYLE_CODES[:reset]}m"
        return colorized
      end

      private

      # Apply a given style:
      # - style: the style as a hash or a string.
      def apply(style)
        if style.kind_of?(Hash)
          for key, value in style
            check_attribute_value(key, value)
            eval("@#{key} = #{value.inspect}")
          end
        elsif style.kind_of?(String)
          for pair in style.split(',')
            key, value = pair.split(':')
            key = SHORT_STYLE_KEYS[key] || key
            key = key.to_sym
            if key == :line_length
              value = value.to_i
            elsif key == :line_character
              value = ' ' if not value or value.length == 0
            else
              value = value.to_sym if value
            end
            check_attribute_value(key, value)
            eval("@#{key} = #{value.inspect}")
          end
        else
          raise "Style must ne a Hash or a String" if style
        end
      end

      def check_attribute_value(attribute, value)
        raise "Attribute '#{attribute}' must be a symbol" unless
          attribute.kind_of?(Symbol)
        raise "Unknown attribute '#{attribute}'" unless
          instance_variable_defined?("@#{attribute}".to_sym)
        if attribute == :line_length
          raise "'line_length' attribute must be an integer" unless
            value.kind_of?(Integer)
        elsif attribute == :line_character
          raise "'line_character' must be a single character" unless
            value.kind_of?(String) and value.length == 1
        else
          raise "Value '#{value}' should be a symbol" unless
            value.kind_of?(Symbol)
          if attribute.to_s[-6..-1] == '_style'
            raise "Unkown style '#{value}'" if not STYLES.member?(value)
          else
            raise "Unkown color '#{value}'" if not COLORS.member?(value)
          end
        end
      end

    end

  end

end
