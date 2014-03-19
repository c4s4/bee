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
require 'bee_listener'
require 'bee_console_formatter'
require 'getoptlong'
require 'syck'
require 'yaml'

module Bee

  module Console

    # Command line help.
    HELP = <<'EOF'
Usage: bee [options] [targets]
-V             Print version and exit.
-h             Print help about usage and exit.
-b             Print help about build and exit.
-n             Don't actually run any commands; just print them.
-k task        Print help about tasks in a package (writing "foo.?") or a 
               given one (writing "foo.bar") and exit.
-e egg         Print help about templates in a given package (writing 
               "foo.?") or a given one (writing "foo.bar") and exit.
-p name=value  Set a named property with a given value.
-t egg         Run a given egg to generate a template project.
-v             Enable verbose mode.
-s style       Define style for output (see documentation).
-c             Use color scheme for output (if running in color terminal).
-w             Use black and white output (default).
-f file        Build file to run (defaults to "build.yml").
-r             Look for build file recursively up in file system.
-l             Print bee logo on console.
-R resource    Print given resource (such as ':bee:clean.yml') on console.
-a             Print list of available targets.
-o             Print list of available options.
-x             Print list of available tasks.
-y             Print list of available templates.
targets        Targets to run (default target if omitted).
EOF
    # Options descriptions.
    OPTIONS = [
        ['--version', '-V', GetoptLong::NO_ARGUMENT],
        ['--help', '-h', GetoptLong::NO_ARGUMENT],
        ['--help-build', '-b', GetoptLong::NO_ARGUMENT],
        ['--help-task','-k', GetoptLong::REQUIRED_ARGUMENT],
        ['--help-template','-e', GetoptLong::REQUIRED_ARGUMENT],
        ['--dry-run', '-n', GetoptLong::NO_ARGUMENT],
        ['--property', '-p', GetoptLong::REQUIRED_ARGUMENT],
        ['--template', '-t', GetoptLong::REQUIRED_ARGUMENT],
        ['--verbose', '-v', GetoptLong::NO_ARGUMENT],
        ['--style', '-s', GetoptLong::REQUIRED_ARGUMENT],
        ['--color', '-c', GetoptLong::NO_ARGUMENT],
        ['--black-and-white', '-w', GetoptLong::NO_ARGUMENT],
        ['--file', '-f', GetoptLong::REQUIRED_ARGUMENT],
        ['--recursive', '-r', GetoptLong::NO_ARGUMENT],
        ['--logo', '-l', GetoptLong::NO_ARGUMENT],
        ['--resource', '-R', GetoptLong::REQUIRED_ARGUMENT],
        ['--targets', '-a', GetoptLong::NO_ARGUMENT],
        ['--options', '-o', GetoptLong::NO_ARGUMENT],
        ['--tasks', '-x', GetoptLong::NO_ARGUMENT],
        ['--templates', '-y', GetoptLong::NO_ARGUMENT],
    ]
    # Name for default build file.
    DEFAULT_BUILD_FILE = 'build.yml'
    # Exit value on error parsing command line
    EXIT_PARSING_CMDLINE = 1
    # Exit value on build error
    EXIT_BUILD_ERROR = 2
    # Exit value on unknown error
    EXIT_UNKNOWN_ERROR = 3
    # Exit value on user interruption
    EXIT_INTERRUPT_ERROR = 4
    # Bee options environment variable.
    BEE_OPT_ENV = 'BEEOPT'
    # Bee text logo (generated with http://www.network-science.de/ascii/)
    BEE_LOGO = <<"EOF"
        _                                                                 
       | |__   ___  ___                                                   
 ____  | '_ \\ / _ \\/ _ \\  _____ _____ _____ _____ _____ _____ _____ _____ _____
|____| | |_) |  __/  __/ |_____|_____|_____|_____|_____|_____|_____|_____|_____|
       |_.__/ \\___|\\___|  #{Bee.version.ljust(8)}                     http://bee.rubyforge.org

EOF

    # Parse command line and return parsed arguments.
    # - arguments: command line arguments.
    def self.parse_command_line(arguments)
      arguments = arguments.clone
      version = false
      help = false
      help_build = false
      help_task = false
      help_template = false
      properties = {}
      task = nil
      dry_run = false
      template = nil
      verbose = false
      style = nil
      color = false
      file = DEFAULT_BUILD_FILE
      recursive = false
      logo = false
      resource = nil
      print_targets = false
      print_options = false
      print_tasks = false
      print_templates = false
      targets = []
      # read options in BEEOPT environment variable
      options = ENV[BEE_OPT_ENV]
      options.split(' ').reverse.each { |option| arguments.unshift(option) } if
        options
      # parse command line arguments
      old_argv = ARGV
      ARGV.replace(arguments)
      opts = GetoptLong.new(*OPTIONS)
      opts.each do |opt, arg|
        case opt
        when '--version'
          version = true
        when '--help'
          help = true
        when '--help-build'
          help_build = true
        when '--help-task'
          help_task = true
          task = arg
        when '--help-template'
          help_template = true
          template = arg
        when '--dry-run'
          dry_run = true
          verbose = true
        when '--property'
          name, value = parse_property(arg)
          properties[name] = value
        when '--template'
          template = arg
        when '--verbose'
          verbose = true
        when '--style'
          style = arg
        when '--color'
          color = true
        when '--black-and-white'
          color = false
        when '--file'
          file = arg
        when '--recursive'
          recursive = true
        when '--logo'
          logo = true
        when '--resource'
          resource = arg
        when '--targets'
          print_targets = true
        when '--options'
          print_options = true
        when '--tasks'
          print_tasks = true
        when '--templates'
          print_templates = true
        end
      end
      targets = Array.new(ARGV)
      ARGV.replace(old_argv)
      return version, help, help_build, help_task, task, help_template,
             template, properties, dry_run, verbose, style, color, file,
             recursive, logo, resource, print_targets, print_options,
             print_tasks, print_templates, targets
    end

    # Parse a command line property.
    # - property: property definition as "name=value".
    # Return: name and value of the property.
    def self.parse_property(property)
      begin
        index = property.index('=')
        raise "No = sign (should be 'name=value')" if not index
        name = property[0..index-1]
        value = YAML::load(property[index+1..-1])
        return name, value
      rescue
        raise "Error parsing property '#{property}': #{$!}"
      end
    end

    # Start build from command line.
    # - arguments: command line arguments.
    def self.start_command_line(arguments)
      STDOUT.sync = true
      begin
        version, help, help_build, help_task, task, help_template,
          template, properties, dry_run, verbose, style, color, file,
          recursive, logo, resource, print_targets, print_options,
          print_tasks, print_templates, targets = parse_command_line(arguments)
      rescue
        puts "ERROR: parsing command line: #{$!}"
        exit(EXIT_PARSING_CMDLINE)
      end
      begin
        formatter = Formatter.new(style, color, verbose)
      rescue
        puts "ERROR: bad format string '#{style}'"
        exit(EXIT_PARSING_CMDLINE)
      end
      begin
        puts BEE_LOGO if logo
        if version
          puts Bee.version
        elsif help
          puts HELP
        elsif help_build
          build = Build.load(file, recursive, properties)
          puts formatter.help_build(build)
        elsif help_task
          puts formatter.help_task(task)
        elsif help_template
          puts formatter.help_template(template)
        elsif template
          file = Bee::Util::find_template(template)
          listener = Bee::Listener.new(formatter)
          build = Build.load(file, false, properties)
          build.run(targets, listener, dry_run)
        elsif resource
          raise Bee::Util::BuildError.new("'#{resource}' is not a valid resource") if
            !Util::resource?(resource)
          begin
            puts File.read(Bee::Util::resource_path(resource))
          rescue Exception
            raise Bee::Util::BuildError.new("Resource '#{resource}' not found")
          end
        elsif print_targets
          begin
            build = Build.load(file)
            targets = build.targets.hash.keys
            targets += build.targets.alias.keys if build.targets.alias
          rescue Exception
            targets = []
          end
          print targets.sort.join(' ')
        elsif print_options
          print OPTIONS.map {|o| o[0]}.sort.join(' ')
        elsif print_tasks
          print Bee::Task::PackageManager.list_tasks.join(' ')
        elsif print_templates
          print Bee::Task::PackageManager.list_templates.join(' ')
        else
          listener = Listener.new(formatter)
          build = Build.load(file, recursive, properties)
          build.run(targets, listener, dry_run)
          puts formatter.format_success('OK')
        end
      rescue Bee::Util::BuildError
        puts formatter.format_error_message($!)
        exit(EXIT_BUILD_ERROR)
      rescue Interrupt
        puts "\n#{formatter.format_error('ERROR')}: Build was interrupted!"
        puts $!.backtrace.join("\n") if verbose
        exit(EXIT_INTERRUPT_ERROR)
      rescue Exception
        puts "#{formatter.format_error('ERROR')}: #{$!}"
        puts $!.backtrace.join("\n")
        exit(EXIT_UNKNOWN_ERROR)
      end
    end

  end

end
