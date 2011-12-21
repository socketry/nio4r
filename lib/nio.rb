require 'nio/version'

if defined?(JRUBY_VERSION)
  require 'java'
  require 'nio/jruby/channel'
else
  # Temporary!
  raise 'zomg this only works on jruby!!!'
end

module NIO
end

# TIMTOWTDI!!!
Nio = NIO