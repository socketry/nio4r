module NIO
  # Selectors monitor IO objects for events of interest
  class Selector
    java_import "java.nio.channels.Selector"
    java_import "java.nio.channels.SelectionKey"

    # Convert nio4r interest symbols to Java NIO interest ops
    def self.sym2iops(interest)
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

    # Convert Java NIO interest ops to the corresponding Ruby symbols
    def self.iops2sym(interest_ops)
      case interest_ops
      when SelectionKey::OP_READ
        :r
      when SelectionKey::OP_WRITE
        :w
      when SelectionKey::OP_READ | SelectionKey::OP_WRITE
        :rw
      else raise ArgumentError, "unknown interest op combination: 0x#{interest_ops.to_s(16)}"
      end
    end

    # Create a new NIO::Selector
    def initialize
      @java_selector = Selector.open
      @select_lock = Mutex.new
    end

    # Register interest in an IO object with the selector for the given types
    # of events. Valid event types for interest are:
    # * :r - is the IO readable?
    # * :w - is the IO writeable?
    # * :rw - is the IO either readable or writeable?
    def register(io, interest)
      java_channel = io.to_channel
      java_channel.configureBlocking(false)

      interest_ops = self.class.sym2iops(interest)

      begin
        selector_key = java_channel.register @java_selector, interest_ops
      rescue NativeException => ex
        case ex.cause
        when java.lang.IllegalArgumentException
          raise ArgumentError, "invalid interest type for #{channel}: #{interest}"
        else raise
        end
      end

      NIO::Monitor.new(io, selector_key)
    end

    # Is the given IO object registered with the selector?
    def registered?(io)
      !!io.to_channel.keyFor(@java_selector)
    end

    # Select which monitors are ready
    def select(timeout = nil)
      @select_lock.synchronize do
        if timeout
          ready = @java_selector.select(timeout * 1000)
        else
          ready = @java_selector.select
        end

        return [] unless ready > 0
        @java_selector.selectedKeys.map { |key| key.attachment }
      end
    end

    # Wake up the other thread that's currently blocking on this selector
    def wakeup
      @java_selector.wakeup
      nil
    end

    # Close this selector
    def close
      @java_selector.close
    end

    # Is this selector closed?
    def closed?
      !@java_selector.isOpen
    end
  end
end
