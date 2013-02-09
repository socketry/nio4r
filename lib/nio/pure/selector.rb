module NIO::Pure
  # Selectors monitor IO objects for events of interest
  module Selector
    # Create a new NIO::Selector
    def initialize
      @selectables = {}

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
      raise ArgumentError, "this IO is already registered with the selector" if @selectables[io]

      monitor = NIO::Monitor.new(io, interest, self)
      @selectables[io] = monitor

      monitor
    end

    # Deregister the given IO object from the selector
    def deregister(io)
      monitor = @selectables.delete io
      monitor.close(false) if monitor and not monitor.closed?
      monitor
    end

    # Is the given IO object registered with the selector?
    def registered?(io)
      @selectables.has_key? io
    end

    # Select which monitors are ready
    def select(timeout = nil)
      readers, writers = [@wakeup], []

      @selectables.each do |io, monitor|
        readers << io if monitor.interests == :r || monitor.interests == :rw
        writers << io if monitor.interests == :w || monitor.interests == :rw
        monitor.readiness = nil
      end

      ready_readers, ready_writers = Kernel.select readers, writers, [], timeout
      return unless ready_readers # timeout or wakeup
      
      selected_monitors = Set.new

      ready_readers.each do |io|
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
          monitor = @selectables[io]
          monitor.readiness = :r
          selected_monitors << monitor
        end
      end
      
      ready_writers.each do |io|
        monitor = @selectables[io]
        monitor.readiness = case monitor.readiness
        when :r
          :rw
        else
          :w
        end
        selected_monitors << monitor
      end
      
      if block_given?
        selected_monitors.each do |m|
          yield m
        end
        selected_monitors.size
      else
        selected_monitors
      end
    end

    # Wake up a thread that's in the middle of selecting on this selector, if
    # any such thread exists.
    #
    # Invoking this method more than once between two successive select calls
    # has the same effect as invoking it just once. In other words, it provides
    # level-triggered behavior.
    def wakeup
      # Send the selector a signal in the form of writing data to a pipe
      @waker << "\0"
      nil
    end

    # Close this selector and free its resources
    def close
      return if @closed

      @wakeup.close rescue nil
      @waker.close rescue nil
      @closed = true
    end

    # Is this selector closed?
    def closed?; @closed end
    
    def empty?
      @selectables.empty?
    end
  end
end
