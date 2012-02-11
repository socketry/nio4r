module NIO
  # Monitors watch IO objects for specific events
  class Monitor
    attr_reader :io, :interests
    attr_accessor :value, :readiness

    # :nodoc
    def initialize(io, interests)
      unless io.is_a?(IO)
        if IO.respond_to? :try_convert
          io = IO.try_convert(io)
        elsif io.respond_to? :to_io
          io = io.to_io
        end

        raise TypeError, "can't convert #{io.class} into IO" unless io.is_a? IO
      end

      @io, @interests = io, interests
      @closed = false
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
