require 'nio/version'
require 'nio/core_ext'

# New I/O for Ruby
module NIO
  # NIO implementation, one of the following (as a string):
  # * select: in pure Ruby using Kernel.select
  # * libev: as a C extension using libev
  # * java: using Java NIO
  def self.engine; ENGINE end
end

if ENV["NIO4R_PURE"]
  require 'nio/pure'
  NIO::ENGINE = 'select'
else
  if defined?(JRUBY_VERSION)
    require 'nio/jruby'
    NIO::ENGINE = 'java'
  else
    require 'nio/channel'
    require 'nio4r_ext'
    NIO::ENGINE = 'libev'
  end
end

# TIMTOWTDI!!!
Nio = NIO