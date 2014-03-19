#!/usr/bin/env ruby
#
# Sample Sinatra server. You can get sinatra typing: 'gem install sinatra'.

require 'rubygems'
require 'sinatra'

get '/hello/:name' do
  "Hello #{ params[:name]}!"
end
