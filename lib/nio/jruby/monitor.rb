module NIO
  # Monitors watch Channels for specific events
  class Monitor
    attr_accessor :value

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

    # Is this monitor closed?
    def closed?; @closed; end

    # Deactivate this monitor
    def close
      @closed = true
    end
  end
end
