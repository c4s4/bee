#!/usr/bin/env ruby
#
# Test suite for sample Ruby application.

require 'test/unit'
$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'application'

# Test sample Ruby application
class TestApplication < Test::Unit::TestCase
  
  # Run before each test
  def setup
  end

  # Test hello method
  def test_hello
    expected = 'Hello Foo!'
    actual = hello('Foo')
    assert_equal(expected, actual)
  end

end
