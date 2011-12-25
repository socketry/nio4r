require 'nio/version'

if defined?(JRUBY_VERSION)
  require 'java'
  require 'nio/jruby/monitor'
  require 'nio/jruby/selector'
else
  # Temporary!
  require 'nio/monitor'
  require 'nio/selector'
end

# New I/O for Ruby
module NIO
end

# TIMTOWTDI!!!
Nio = NIO