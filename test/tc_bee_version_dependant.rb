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
require 'fileutils'
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'bee_version_dependant'
require 'test/unit'

class TestBeeVersionDependant < Test::Unit::TestCase

  def test_to_version
    assert_equal([1, 2, 3], Bee::VersionDependant::to_version('1.2.3'))
    assert_equal([1, 2], Bee::VersionDependant::to_version('1.2'))
    assert_equal([1], Bee::VersionDependant::to_version('1'))
  end

  def test_get_ruby_version
    ruby_version = Bee::VersionDependant::ruby_version
    assert_equal(RUBY_VERSION, ruby_version.join('.'))
    assert(ruby_version[0].kind_of?(Numeric))
  end

  def test_compare_versions
    assert_equal(0, Bee::VersionDependant::compare_versions([], []))
    assert_equal(0, Bee::VersionDependant::compare_versions([1], [1]))
    assert_equal(0, Bee::VersionDependant::compare_versions([1, 2, 3], [1, 2, 3]))
    assert_equal(-1, Bee::VersionDependant::compare_versions([], [1]))
    assert_equal(-1, Bee::VersionDependant::compare_versions([1], [2]))
    assert_equal(-1, Bee::VersionDependant::compare_versions([1], [1, 0]))
    assert_equal(1, Bee::VersionDependant::compare_versions([1], []))
    assert_equal(1, Bee::VersionDependant::compare_versions([2], [1]))
    assert_equal(1, Bee::VersionDependant::compare_versions([1, 0], [1]))
  end

  def test_ruby_greater_than
    assert(Bee::VersionDependant::ruby_greater_than('1.0'))
    assert(Bee::VersionDependant::ruby_lower_than('4.0'))
  end

  def test_compare_versions
    assert(Bee::VersionDependant::compare_versions('1.2.3',   '2.3.4') < 0)
    assert(Bee::VersionDependant::compare_versions('1.2.3',   '1.3.4') < 0)
    assert(Bee::VersionDependant::compare_versions('1.2.3',   '1.2.4') < 0)
    assert(Bee::VersionDependant::compare_versions('1.2.3',   '1.2.3') == 0)
    assert(Bee::VersionDependant::compare_versions('1.2',     '1.2.0') < 0)
    assert(Bee::VersionDependant::compare_versions('1.2.0.0', '1.2')   > 0)
    assert(Bee::VersionDependant::compare_versions('1.2',     '1.2.1') < 0)
  end

end
