require 'nio/version'
require 'nio/core_ext'

if defined?(JRUBY_VERSION)
  require 'nio/jruby'
else
  # Temporary!
  require 'nio/pure'
end

# New I/O for Ruby
module NIO
end

# TIMTOWTDI!!!
Nio = NIO