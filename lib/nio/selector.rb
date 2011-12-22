module NIO
  # Selectors monitor channels for events of interest
  class Selector
    # Create a new NIO::Selector
    def initialize
      @selectables = {}
      @select_lock = Mutex.new
    end

    # Register interest in an NIO::Channel with the selector for the given types
    # of events. Valid event types for interest are:
    # * :r - is the channel readable?
    # * :w - is the channel writeable?
    # * :rw - is the channel either readable or writeable?
    def register(selectable, interest)
      if selectable.is_a? NIO::Channel
        channel = selectable
      else
        channel = selectable.channel
      end

      channel.blocking = false
      monitor = Monitor.new(channel, interest)

      @select_lock.synchronize do
        @selectables[channel] = monitor
      end

      monitor
    end

    # Select which monitors are ready
    def select(timeout = nil)
      @select_lock.synchronize do
        readers, writers = [], []

        @selectables.each do |channel, monitor|
          readers << channel.to_io if monitor.interests == :r || monitor.interests == :rw
          writers << channel.to_io if monitor.interests == :w || monitor.interests == :rw
        end

        ready_readers, ready_writers = Kernel.select readers, writers, [], timeout

        results = ready_readers || []
        results.concat ready_writers if ready_writers

        results.map! { |io| @selectables[io.channel] }
    # Close this selector and free its resources
    def close
      @lock.synchronize do
        return if @closed
      
        @wakeup.close rescue nil
        @waker.close rescue nil
        @closed = true
      end
    end
    
    # Is this selector closed?
    def closed?; @closed end
  end
end
