module NIO
  # Selectors monitor IO objects for events of interest
  class Selector
    # Create a new NIO::Selector
    def initialize
      @selectables = {}
      @lock = Mutex.new

      # Other threads can wake up a selector
      @wakeup, @waker = IO.pipe
      @closed = false
    end

    # Register interest in an IO object with the selector for the given types
    # of events. Valid event types for interest are:
    # * :r - is the IO readable?
    # * :w - is the IO writeable?
    # * :rw - is the IO either readable or writeable?
    def register(io, interest)
      @lock.synchronize do
        raise ArgumentError, "this IO is already registered with the selector" if @selectables[io]

        monitor = Monitor.new(io, interest)
        @selectables[io] = monitor

        monitor
      end
    end

    # Deregister the given IO object from the selector
    def deregister(io)
      @lock.synchronize do
        monitor = @selectables.delete io
        monitor.close if monitor
        monitor
      end
    end

    # Is the given IO object registered with the selector?
    def registered?(io)
      @lock.synchronize { @selectables.has_key? io }
    end

    # Select which monitors are ready
    def select(timeout = nil)
      @lock.synchronize do
        readers, writers = [@wakeup], []

        @selectables.each do |io, monitor|
          readers << io if monitor.interests == :r || monitor.interests == :rw
          writers << io if monitor.interests == :w || monitor.interests == :rw
        end

        ready_readers, ready_writers = Kernel.select readers, writers, [], timeout
        return unless ready_readers # timeout or wakeup

        results = ready_readers
        results.concat ready_writers if ready_writers

        results.map! do |io|
          if io == @wakeup
            # Clear all wakeup signals we've received by reading them
            # Wakeups should have level triggered behavior
            begin
              @wakeup.read_nonblock(1024)

              # Loop until we've drained all incoming events
              redo
            rescue Errno::EWOULDBLOCK
            end

            return
          else
            @selectables[io]
          end
        end
      end
    end

    # Wake up other threads waiting on this selector
    def wakeup
      # Send the selector a signal in the form of writing data to a pipe
      @waker << "\0"
      nil
    end

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
