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
      
      @selectables[io] = Monitor.new(io, interests, self)
    end
    
    def deregister(io)
      monitor = @selectables.delete io
      if monitor
        monitor.close(false)
      end
      monitor
    end
  end
end