module NIO
  # Channels provide the glue between IO objects and the NIO subsystem
  class Channel
    attr_reader :io

    # Create a new NIO::Channel from a Ruby IO object
    def initialize(io)
      @io = io
      @blocking = true

      # YAGNI, as in you are going to need it, even though it seems silly now
      @lock = Mutex.new
    end

    # Is this channel blocking?
    def blocking?
      @lock.synchronize { @blocking }
    end
    alias_method :blocking, :blocking?

    # Configure blocking mode for this channel
    def blocking=(mode)
      case mode
      when TrueClass, FalseClass
        @lock.synchronize { @blocking = mode }
      else raise TypeError, "expected a boolean value"
      end
    end

    # Obtain an IO object for this channel
    def to_io
      @io
    end
  end
end
