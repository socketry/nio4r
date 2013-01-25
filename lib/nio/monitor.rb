module NIO
  # Monitors watch IO objects for specific events
  class Monitor
    attr_reader :io, :selector #, :interests
    attr_accessor :value #, :key
    
    # :nodoc
    def initialize(io, interests, selector)
      @io, @selector = io, selector
      super(io, interests, selector)
    end

    # Is this monitor closed?
    def closed?
      not selector[io] == self
    end
    
    # Is the IO object readable?
    def readable?
      readiness == :r || readiness == :rw
    end
  
    # Is the IO object writable?
    def writable?
      readiness == :w || readiness == :rw
    end
    alias_method :writeable?, :writable?
  end
end