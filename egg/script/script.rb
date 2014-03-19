#!/usr/bin/env ruby
#
# Sample Ruby source file.

require 'getoptlong'

HELP = 'Usage: <%= name %>.rb [-h] [-t times] who
-h        To print this help screen
-t times  The number of times to great
who       To name the person to great'

# Great a given person.
# - who: the person to great.
# - times: number of times to great (defaults to 1).
def hello(who, times=1)
  times.times do
    puts "Hello #{who}!"
  end
end

# parse command line
if __FILE__ == $0
  who = 'World'
  times = 1
  opts = GetoptLong.new(
    ["--help",  "-h", GetoptLong::NO_ARGUMENT],
    ["--times", "-t", GetoptLong::REQUIRED_ARGUMENT]
  )
  opts.each do |opt, arg|
    case opt
    when '--help'
      puts HELP
      exit 0
    when '--times'
      times = arg.to_i
    end
  end
  if ARGV.length > 1
    puts HELP
    exit 0
  end
  if ARGV.length == 1
    who = ARGV[0]
  end
  hello(who, times)
end
