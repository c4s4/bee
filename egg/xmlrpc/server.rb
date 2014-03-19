#!/usr/bin/env ruby
#
# Test Ruby XML-RPC server.

require 'xmlrpc/server'

server = XMLRPC::Server.new(8000)
server.add_handler('test.hello') do |who|
  "Hello #{who}!"
end
server.serve
