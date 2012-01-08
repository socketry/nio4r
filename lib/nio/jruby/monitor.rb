module NIO
  # Monitors watch Channels for specific events
  class Monitor
    attr_accessor :value, :io

    # :nodoc
    def initialize(io, selection_key)
      @io, @key = io, selection_key
      selection_key.attach self
      @closed = false
    end

    # Obtain the interests for this monitor
    def interests
      Selector.iops2sym @key.interestOps
    end

    # What is the IO object ready for?
    def readiness
      Selector.iops2sym @key.readyOps
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

    # Is this monitor closed?
    def closed?; @closed; end

    # Deactivate this monitor
    def close
      @closed = true
    end
  end
end
