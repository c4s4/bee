require 'yaml'

object = YAML::load(File.read(ARGV[0]))
puts object.inspect
