#!/usr/bin/env ruby
#
# Test Ruby XML-RPC client.

require 'xmlrpc/client'

client = XMLRPC::Client.new('localhost', '/', 8000)
puts client.call('test.hello', 'World')
