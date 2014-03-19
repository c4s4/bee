@echo off
if not "%~f0" == "~f0" goto WinNT
ruby -Sx "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofruby
:WinNT
"%~d0%~p0ruby" -x "%~f0" %*
goto endofruby
#!/usr/bin/env ruby

# Launching script.

$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'
require 'application'

parse_command_line

__END__
:endofruby
