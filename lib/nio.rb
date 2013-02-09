require 'thread'
require 'socket'
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
  require 'nio/pure/monitor'
  require 'nio/pure/selector'

  NIO::ENGINE = 'select'
  modyool = NIO::Pure
else
  require 'nio4r_ext'

  if defined?(JRUBY_VERSION)
    require 'java'
    require 'jruby'
    org.nio4r.Nio4r.new.load(JRuby.runtime, false)
    NIO::ENGINE = 'java'
  else
    NIO::ENGINE = 'libev'
    modyool = NIO::Libev
  end
end

#Shared code for locking
unless NIO::ENGINE == 'java'
  require 'nio/selector'

  NIO::Selector.send :include, modyool::Selector
  NIO::Selector.threadsafe!
end
