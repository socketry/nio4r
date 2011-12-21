module NIO
  # Channels provide the glue between IO objects and the NIO subsystem
  class Channel
    # Create a new NIO::Channel from a Ruby IO object
    def initialize(io)
      @io = io      
      @java_channel = io.to_channel
    end
  end
end