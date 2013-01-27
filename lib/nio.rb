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

require 'nio/selector'
require 'nio/monitor'


sub_module = nil
if(defined? JRUBY_VERSION)
  NIO::ENGINE = 'java'

  require 'nio/java/monitor'
  require 'nio/java/selector'

  sub_module = NIO::Java
  
else
  if ENV["NIO4R_PURE"]
    require 'nio/pure/selector'
    require 'nio/pure/monitor'
    NIO::ENGINE = 'select'

    sub_module = NIO::Pure
  else
    require 'nio4r_ext'
    require 'nio/libev/selector'
    require 'nio/libev/monitor'
  
    NIO::ENGINE = 'libev'
    sub_module = NIO::Libev
  end
  NIO::Selector.threadsafe!
end

NIO::Selector.send(:include, sub_module::Selector)
NIO::Monitor.send(:include, sub_module::Monitor)

