module NIO
  # Monitors watch Channels for specific events
  class Monitor
    attr_reader :interests

    # :nodoc
    def initialize(channel, interests)
      @channel, @interests = channel, interests
    end
  end
end
