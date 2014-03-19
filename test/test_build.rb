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
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'bee_context'
require 'bee_task_packagemanager'
require 'test_build_listener'

# Empty build for testing purpose. Contains a single context.
class TestBuild
  
  attr_reader :context
  attr_reader :listener
  attr_reader :package_manager
  
  def initialize(context=Bee::Context.new(),
                 listener=TestBuildListener.new())
    @context = context
    @listener = listener
    @package_manager = Bee::Task::PackageManager.new(self)
  end
  
end
