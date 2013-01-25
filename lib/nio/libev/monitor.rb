#The pure version of monitor is identical to the libev version
require 'nio/pure/monitor'

module NIO::Libev
  Monitor = NIO::Pure::Monitor
end