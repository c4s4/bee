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

require 'rubygems'
$:.unshift(File.expand_path(File.dirname(__FILE__)))
require 'tmp_test_case'
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require 'bee_console'
require 'bee_properties'

class TestBugs < TmpTestCase

  # Bug 1 demonstration. Properties are evaluated after parent loading which
  # makes an error because property 'foo' is not set. Properties should be
  # evaluated just before running the build. FIXED.
  def test_bug_1_demo
    parent = <<'EOF'
- properties:
    foo: ~
    bar: "#{foo.gsub(/-/, '+')}"
EOF
    son = <<'EOF'
- build: son
  default: test
  extends: parent.yml

- properties:
    foo: "toto-tata"

- target: test
  script:
  - print: :bar
EOF
    write_tmp_file('parent.yml', parent)
    path = write_tmp_file('build.yml', son)
    assert_output(/toto\+tata/) do
      arguments = ['-f', path]
      Bee::Console.start_command_line(arguments)
    end
  end

  def test_bug_1_properties
    properties = Bee::Properties.new({:foo => 'toto-tata'})
    properties.extend({:foo => nil, :bar => '#{foo.gsub(/-/, "+")}'})
    assert_equal({:foo=>'toto-tata', :bar=>'#{foo.gsub(/-/, "+")}'},
                 properties.expressions)
  end

end

