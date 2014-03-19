#!/usr/bin/env ruby

# Greet a given person.
# - who: the person to greey.
def hello(who)
  return "Hello #{who}!"
end

# command line help
HELP = 'hello [-h] who ...
-h      To print this help screen
who     The person(s) to greet'

# parse command line arguments
require 'getoptlong'
opts = GetoptLong.new(['--help', '-h', GetoptLong::NO_ARGUMENT])
begin
  opts.each do |opt, arg|
    case opt
    when '--help'
      puts HELP
      exit
    end
  end
rescue
  puts HELP
  exit
end
for who in ARGV
  puts hello(who)
end
