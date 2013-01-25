module NIO::Java
  module Selector
    attr_reader :selector

    def initialize(*args)
      super(*args)
      @selector = java.nio.channels.Selector.open()
    end
    
    def [](io)
      selector.selectNow # Handles any cancellations

      key = io.to_channel.keyFor(selector)
      
      key && key.attachment
    end
    
    def register(io, interests)
      raise TypeError, "io is a #{io.class.name}" unless io.is_a? IO
      
      channel = io.to_channel
      channel.configure_blocking false
      
      # A key may still exist for the channel if it was cancelled
      # A select cycle will clean out cancelled keys
      selector.selectNow if channel.keyFor(selector)
      
      monitor = NIO::Monitor.new(io, interests, self)

      monitor
    end
    
    def deregister(io)
      monitor = self[io]
      monitor && monitor.close
            
      monitor
    end
    
    def close
      selector.close
    end
    
    def closed?
      !selector.isOpen
    end
    
    def select(timeout = nil)
      count = if(timeout.nil?)
        selector.select
      else
        timeout = (1000 * timeout).to_i
        if(timeout == 0)
          selector.selectNow
        else
          selector.select(timeout)
        end
      end

      sk = selector.selectedKeys
      return nil if sk.size == 0
      sk.synchronized do
        ret = if block_given?
          sk.each do |k|
            yield k.attachment
          end
          sk.size
        else
          sk.to_a.collect { |k| k.attachment }
        end
        sk.clear
        ret
      end
    end
    
    def registered?(io)
      self[io]
    end
    
    def empty?
      keys = selector.keys
      keys.synchronized do
        keys.empty?
      end
    end
    
    def wakeup
      raise IOError, "selector is closed" if closed?
      selector.wakeup
    end
  end
end