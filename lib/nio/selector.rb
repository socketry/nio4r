require 'monitor'

module NIO
  # Selectors monitor IO objects for events of interest
  class Selector
    def initialize
      @selectables = {};
      @lock = ::Monitor.new
      super
    end
    
    def empty?
      @selectables.empty?
    end
    
    # Register interest in an IO object with the selector for the given types
    # of events. Valid event types for interest are:
    # * :r - is the IO readable?
    # * :w - is the IO writeable?
    # * :rw - is the IO either readable or writeable?
    # TODO: Synchronize
    def register(io, interests)
      raise ArgumentError, "this IO is already registered with the selector" if @selectables[io]
      
      m = @selectables[io] = Monitor.new(io, interests, self)
      reregister(m)
      m
    end
    
    # Deregister the given IO object from the selector
    def deregister(io)
      monitor = @selectables.delete io
      if(monitor)
        native_deregister(monitor)
      end
      monitor
    end
    
    def reregister(monitor)
      native_reregister(monitor)
    end

    # Is the given IO object registered with the selector?
    def registered?(io)
      @selectables.has_key?(io)
    end
    
    def select(timeout = nil, &block)
      raise ArgumentError, "time interval must be positive" if(timeout && timeout < 0)
      native_select(timeout, &block)
    end

    def empty?
      @selectables.empty?
    end
    
    def self.lock_methods(*methods)
      methods.each do |m|
        mname = :"#{m}_without_lock"
        define_method :"#{m}_with_lock" do |*args, &block|
          # @lock.synchronize do
            send mname, *args, &block
          # end
        end
        alias_method :"#{m}_without_lock", m
        alias_method m, :"#{m}_with_lock"
      end
    end
    
    def self.threadsafe!
      lock_methods :select, :register, :reregister, :deregister, :registered?, :close, :closed?, :empty?
    end
  end
end
