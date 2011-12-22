require 'nio/version'
require 'nio/core_ext'

if ENV["NIO4R_PURE"]
  require 'nio/pure'
else
  if defined?(JRUBY_VERSION)
    require 'nio/jruby'
  else
    require 'nio4r_ext'
  end
end

# New I/O for Ruby
module NIO
end

# TIMTOWTDI!!!
Nio = NIO