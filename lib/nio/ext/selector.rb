STDERR.puts("Loading RB extensions")
module NIO
  class Selector

    def initialize
      @selectables = {};
      @lock = Mutex.new
    end
    
    def registered?(io)
      @selectables.has_key?(io)
    end
    
    def empty?
      @selectables.empty?
    end
    
    # TODO: Synchronize
    def register(io, interests)
      raise ArgumentError, "this IO is already registered with selector" if @selectables[io]
      
      m = @selectables[io] = Monitor.new(io, interests, self)
      reregister(m)
      m
    end
    
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
  end
end