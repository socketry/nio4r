module NIO
  class Monitor
    attr_accessor :value, :interests, :readiness, :io
    attr_reader   :selector
    
    def initialize(io, interests, selector)
      self.io        = io
      self.interests = interests
      @selector      = selector
    end
    
    def readable?
      readiness == :r || readiness == :rw
    end
    
    def writeable?
      readiness == :w || readiness == :rw
    end
    
    alias_method :writable?, :writeable?
    
    def closed?
      !selector.registered?(io)
    end
    
    def close
      selector.deregister(io)
    end
    
  end
end