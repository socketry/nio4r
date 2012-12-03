module NIO
  # Selectors monitor IO objects for events of interest
  class Selector
    def initialize
      @selectables = {};
      @lock = Mutex.new
      super
    end
    
    def empty?
      @selectables.empty?
    end
    
    # Register interest in an IO object with the selector for the given types
    # of events. Valid event types for interest are:
    # * :r - is the IO readable?
    # * :w - is the IO writeable?
    # * :rw - is the IO either readable or writeable?
    # TODO: Synchronize
    def register(io, interests)
      raise ArgumentError, "this IO is already registered with the selector" if @selectables[io]
      
      m = @selectables[io] = Monitor.new(io, interests, self)
      reregister(m)
      m
    end
    
    # Deregister the given IO object from the selector
    def deregister(io)
      monitor = @selectables.delete io
      if(monitor)
        native_deregister(monitor)
      end
      monitor
    end
    
    def reregister(monitor)
      native_reregister(monitor)
    end

    # Is the given IO object registered with the selector?
    def registered?(io)
      @selectables.has_key?(io)
    end

    def empty?
      @selectables.empty?
    end
  end
end
