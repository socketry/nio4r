require 'thread'
require 'nio/version'

# New I/O for Ruby
module NIO
  # NIO implementation, one of the following (as a string):
  # * select: in pure Ruby using Kernel.select
  # * libev: as a C extension using libev
  # * java: using Java NIO
  def self.engine; ENGINE end
end

if ENV["NIO4R_PURE"]
  require 'nio/monitor'
  require 'nio/selector'
  NIO::ENGINE = 'select'
else
  require 'nio4r_ext'

  if defined?(JRUBY_VERSION)
    require 'java'
    org.nio4r.Nio4r.new.load(JRuby.runtime, false)

    require 'nio/jruby/monitor'
    require 'nio/jruby/selector'
    NIO::ENGINE = 'java'
  else
    NIO::ENGINE = 'libev'
  end
end

# TIMTOWTDI!!!
Nio = NIO
