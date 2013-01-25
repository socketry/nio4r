module NIO::Java
  module Monitor
    java_import java.nio.channels.SelectionKey

    READ_OPS  = (SelectionKey::OP_ACCEPT | SelectionKey::OP_READ)
    WRITE_OPS = (SelectionKey::OP_CONNECT | SelectionKey::OP_WRITE)

    def initialize(io, interests, selector)
      channel.register(selector.selector, 0)
      self.key.attach self
      self.interests = interests
    end
    
    def readiness
      ops = key.readyOps

      r = (ops & READ_OPS  != 0)
      w = (ops & WRITE_OPS != 0)

      return :rw if(r && w)
      return :r  if(r)
      return :w  if(w)
    end

    # returns the interests for this monitor as Java-style bitmask, 
    # taking into account the socket's validOps
    def interests=(interests)
      validOps = key.channel.validOps
      iops = case(interests)
      when :r
        validOps & READ_OPS
      when :w
        validOps & WRITE_OPS
      else
        validOps & (READ_OPS | WRITE_OPS)
      end
      key.interestOps(iops)
    end
    
    def interests
      iops = key.interestOps
      if((iops & READ_OPS) != 0 && (iops & WRITE_OPS) != 0)
        :rw
      elsif((iops & READ_OPS) != 0)
        :r
      elsif((iops & WRITE_OPS) != 0)
        :w
      else
        nil
      end
    end
    
    # def closed?
    #   !key || !key.isValid
    # end
    # 
    def close
      key.cancel
    end
    
    def channel
      io.to_channel
    end
    
    def key
      channel.keyFor(selector.selector)
    end
  end
end