module NIO
  module Pure
    module Monitor
      attr_accessor :interests
      attr_accessor :readiness
      
      def initialize(io, interests, selector)
        self.interests = interests
      end
      
      # Deactivate this monitor
      def close
        selector.deregister(io)
      end

    end
  end
end