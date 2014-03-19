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
require 'bee_console_style'
require 'syck'
require 'yaml'

module Bee

  module Console

    # Class to format build output on console.
    class Formatter

      include Bee::Util::BuildErrorMixin

      # Minimum duration to print on console even if not verbose (in seconds)
      AUTO_DURATION = 60

      # Construct formatting order
      CONSTRUCT_FORMATS = {
        'if' =>    ['if', 'then', 'else'],
        'while' => ['while', 'do'],
        'for' =>   ['for', 'in', 'do'],
        'try' =>   ['try', 'catch'],
      }

      # Verbosity indicator
      attr_reader :verbose

      # Constructor.
      # - style: style as a Hash or a String.
      # - color: tells if we use default color scheme. Defaults to false.
      # - verbose: tells if build is verbose. Defaults to false.
      # - outputer: object on which we call print and puts for outputs.
      #   Defaults to Kernel.
      def initialize(style, color=false, verbose=false, outputer=Kernel)
        @style = Bee::Console::Style.new(style, color)
        @verbose = verbose
        @outputer = outputer
      end

      ##########################################################################
      #                       LOW LEVEL OUTPUT METHODS                         #
      ##########################################################################

      # Print a given message on console:
      # - message: the message to print.
      def print(message)
        @outputer.print(message)
      end

      # Puts a given message on console:
      # - message: the message to put.
      def puts(message)
        @outputer.puts(message)
      end

      ##########################################################################
      #                     METHODS CALLED BY LISTENER                         #
      ##########################################################################

      # Print build start message:
      # - build: the started build.
      # - dry_run: tells if we are running in dry mode.
      def print_build_started(build, dry_run)
        if @verbose
          build_type = dry_run ? "dry run of" : "build"
          puts "Starting #{build_type} '#{build.file}'..."
        end
      end

      # Print message when build finished:
      # - duration: the build duration in seconds.
      # - success: tells if build was a success.
      # - exception : exception raised, if any.
      # - last_target: last met target, if any.
      # - last_task: last met task, if any.
      def print_build_finished(duration)
        puts "Built in #{duration} s" if @verbose or duration >= AUTO_DURATION
      end

      # Print target:
      # - target: the target we are running.
      def print_target(target)
        puts format_target(target)
      end

      # Print task:
      # - task: the task we are running.
      def print_task(task)
        puts format_task(task) if @verbose
      end

      ##########################################################################
      #                          FORMATTING METHODS                            #
      ##########################################################################

      # Format a target.
      # - target: target to format.
      def format_target(target)
        name = target.name
        return format_title(name)
      end

      # Format a task.
      # - task: task to format.
      def format_task(task)
        if task.kind_of?(String)
          source = task
        elsif task.kind_of?(Hash)
          if task.key?('rb')
            source = "rb: #{task['rb']}"
          else
            if task.keys.length == 1
              source = format_entry(task)
            else
              source = format_construct(task)
            end
          end
        end
        formatted = '- ' + source.strip.gsub(/\n/, "\n. ")
        styled = @style.style(formatted, :task)
        return styled
      end

      # Format a success string.
      # - string: string to format.
      def format_success(string)
        string = @style.style(string, :success)
        return string
      end

      # Format an error string.
      # - string: string to format.
      def format_error(string)
        string = @style.style(string, :error)
        return string
      end

      # Format error message:
      # - exception: raised exception.
      def format_error_message(exception)
        message = format_error('ERROR')
        message << ": "
        message << exception.to_s
        if exception.kind_of?(Bee::Util::BuildError)
          message << "\nIn target '#{exception.target.name}'" if exception.target
          message << ", in task:\n#{format_task(exception.task)}" if exception.task
        end
        return message
      end

      # Format a description.
      # - title: description title (project, property or target name).
      # - text: description text.
      # - indent: indentation width.
      # - bullet: tells if we must put a bullet.
      def format_description(title, text=nil, indent=0, bullet=true)
        string = ' '*indent
        string << '- ' if bullet
        string << title
        if text and !text.empty?
          string << ": "
          if text.split("\n").length > 1
            string << "\n"
            text.split("\n").each do |line|
              string << ' '*(indent+2) + line.strip + "\n"
            end
          else
            string << text.strip + "\n"
          end
        else
          string << "\n"
        end
        return string
      end

      # Format a title.
      # - title: title to format.
      def format_title(title)
        length = @style.line_length || Bee::Util::term_width
        right = ' ' + @style.line_character*2
        size = length - (title.length + 4)
        size = 2 if size <= 0
        left = @style.line_character*size + ' '
        line = left + title + right
        # apply style
        formatted = @style.style(line, :target)
        return formatted
      end

      ##########################################################################
      #                       HELP FORMATTING METHODS                          #
      ##########################################################################

      # Return help about build.
      # - build: running build.
      def help_build(build)
        build.context.evaluate
        help = ''
        # print build name and description
        if build.name
          help << "build: #{build.name}\n"
        end
        if build.extends
          help << "extends: #{format_list(build.extends.map{|b| b.name})}\n"
        end
        if build.description
          help << format_description('description', build.description, 0, false)
        end
        # print build properties
        if build.context.properties.length > 0
          help << "properties:\n"
          for property in build.context.properties.sort
            help << "- #{property}: " +
              "#{format_property_value(build.context.get_property(property))}\n"
          end
        end
        # print build targets
        description = build.targets.description
        if description.length > 0
          help << "targets:\n"
          for name in description.keys.sort
            help << format_description(name, description[name], 0)
          end
        end
        # print default target
        help << "default: #{format_list(build.targets.default)}\n" if
          build.targets.default
        # print alias for targets
        if build.targets.alias and build.targets.alias.keys.length > 0
          help << "alias:\n"
          for name in build.targets.alias.keys.sort
            help << "  #{name}: #{format_list(build.targets.alias[name])}\n"
          end
        end
        return help.strip
      end

      # Return help about task(s).
      # - task: task to print help about (all tasks if nil).
      def help_task(task)
        task = '?' if task == nil or task.length == 0
        package_manager = Bee::Task::PackageManager.new(nil)
        methods = package_manager.help_task(task)
        help = ''
        for method in methods.keys.sort
          text = methods[method].strip
          help << format_title(method)
          help << "\n"
          help << text
          help << "\n"
          if text =~ /Alias for \w+/
            alias_method = text.scan(/Alias for (\w+)/).flatten[0]
            help << "\n"
            help << package_manager.help_task(alias_method)[alias_method].strip
            help << "\n"
          end
        end
        return help
      end

      # Return help about template(s).
      # - template: template to print help about (all templates if nil).
      def help_template(template)
        templates = Bee::Util::search_templates(template)
        help = ''
        for name in templates.keys
          build = YAML::load(File.read(templates[name]))
          properties = nil
          for entry in build
            properties = entry['properties'] if entry['properties']
          end
          description = 'No description found'
          if properties
            if properties['description']
              description = properties['description']
            end
          end
          help << format_title(name)
          help << "\n"
          help << description
          help << "\n"
        end
        return help
      end

      private

      def format_entry(entry)
        return YAML::dump(entry).sub(/---/, '').strip
      end

      def format_construct(construct)
        for key in CONSTRUCT_FORMATS.keys
          if construct.has_key?(key)
            lines = []
            for entry in CONSTRUCT_FORMATS[key]
              lines << format_entry({entry => construct[entry]})
            end
            return lines.join("\n")
          end
        end
        return "UNKNOWN CONSTRUCT"
      end

      def format_property_value(data)
        if data.kind_of?(Hash)
          pairs = []
          for key in data.keys()
            pairs << "#{format_property_value(key)}: #{format_property_value(data[key])}"
          end
          return "{#{pairs.join(', ')}}"
        else
          return data.inspect
        end
      end

      def format_list(list)
        if list.kind_of?(Array)
          if list.length > 1
            return "[#{list.join(', ')}]"
          else
            return list[0]
          end
        else
          return list
        end
      end

    end

  end

end
