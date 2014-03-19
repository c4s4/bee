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

  module Task

    # Package manager is responsible for loading packages and calling tasks.
    class PackageManager

      include Bee::Util::BuildErrorMixin

      # Constructor.
      # - build: the build we are running.
      def initialize(build)
        @build = build
        @packages = {}
      end

      # Run a given task.
      # - task: YAML object for the task to run.
      def run_task(task)
        packaged = task.keys[0]
        package, name = Bee::Util::get_package_name(packaged)
        parameters = @build.context.evaluate_object(task[packaged])
        if not @packages[package]
          @packages[package] = Bee::Task::PackageManager.load_package(package, @build)
        end
        error "Task '#{name}' not found in package '#{package}'" if
          not @packages[package].respond_to?(name)
        @packages[package].send(name, parameters)
      end

      # Get help for a given task.
      # - task: YAML object for the task to run.
      def help_task(task)
        package, name = Bee::Util::get_package_name(task)
        if not @packages[package]
          @packages[package] = Bee::Task::PackageManager.load_package(package, @build)
        end
        help = {}
        if name == '?'
          methods = @packages[package].class.public_instance_methods(false)
          for method in methods
            help[method] = @packages[package].class.method_info(method).comment
          end
          return help
        else
          error "Task '#{name}' not found in package '#{package}'" if
            not @packages[package].respond_to?(name)
          help[task] = @packages[package].class.method_info(name).comment
        end
        return help
      end

      # List all available tasks.
      def self.list_tasks
        names = [nil] + Bee::Util::find_gems(/^bee_/).map {|gem| gem.name[4..-1]}
        tasks = []
        for name in names
          package = self.load_package(name)
          methods = package.class.public_instance_methods(false)
          if name
            methods.map! {|method| "#{name}.#{method}"}
          else
            methods.map! {|method| method.to_s}
          end
          tasks += methods
        end
        return tasks.sort
      end

      # List all available templates.
      def self.list_templates
        gems = Bee::Util::find_gems(/^bee$/, /^bee_/)
        templates = []
        for gem in gems
          gem_path = gem.full_gem_path
          eggs = Dir.glob("#{gem_path}/egg/*.yml").
            map{|p| p[gem_path.length+5..-5]}
          if gem.name != 'bee'
            package = gem.name[4..-1]
            templates += eggs.map{|e| "#{package}.#{e}"}
          else
            templates += eggs
          end
        end
        return templates.sort
      end

      private

      # Load a given package using introspection: we try to instantiate class
      # named after the package capitalized, in module Bee::Task.
      # - package: the package name.
      def self.load_package(package, build=nil)
        package = 'default' if not package
        package.downcase!
        script = "bee_task_#{package}"
        clazz = package.capitalize
        begin
          require script
          return Bee::Task.const_get(clazz).new(build)
        rescue Exception
          raise Bee::Util::BuildError.new("Task package '#{package}' not found")
        end
      end

    end

  end

end
