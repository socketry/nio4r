module NIO
  # Monitors watch IO objects for specific events
  class Monitor
    attr_reader :io, :interests
    attr_accessor :value

    # :nodoc
    def initialize(io, interests)
      @io, @interests = io, interests
    end
  end
end
