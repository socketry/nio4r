module NIO
  # Monitors watch Channels for specific events
  class Monitor
    # :nodoc
    def initialize(selection_key)
      @key = selection_key
      selection_key.attach self
    end
  end
end