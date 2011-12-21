module NIO
  # Selectors monitor channels for events of interest
  class Selector
    java_import "java.nio.channels.SelectionKey"
    java_import "java.nio.channels.spi.SelectorProvider"
    
    # Convert nio4r interest symbols to Java NIO interest ops
    def self.interest_ops(interest)
      case interest
      when :r
        interest = SelectionKey::OP_READ
      when :w
        interest = SelectionKey::OP_WRITE
      when :rw
        interest = SelectionKey::OP_READ | SelectionKey::OP_WRITE
      else raise ArgumentError, "invalid interest type: #{interest}"
      end
    end
    
    # Create a new NIO::Selector
    def initialize
      @java_selector = SelectorProvider.provider.openSelector
    end
    
    # Register interest in an NIO::Channel with the selector for the given types
    # of events. Valid event types for interest are:
    # * :r - is the channel readable?
    # * :w - is the channel writeable?
    # * :rw - is the channel either readable or writeable?
    def register(channel, interest)
      if channel.respond_to? :java_channel
        java_channel = channel.java_channel
      else
        # Attempt to obtain the NIO::Channel for things like IO objects
        java_channel = channel.channel.java_channel
      end
      
      # Set channel to non-blocking mode if it isn't already
      java_channel.configureBlocking(false)
      interest_ops = self.class.interest_ops(interest)
      
      selector_key = java_channel.register @java_selector, interest_ops      
      NIO::Monitor.new(selector_key)
    end
    
    # Select which monitors are ready
    def select
      ready = @java_selector.select
      return [] unless ready > 0      
      @java_selector.selectedKeys.map { |key| key.attachment }
    end
  end
end