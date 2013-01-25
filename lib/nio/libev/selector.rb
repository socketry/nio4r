module NIO
  module Libev
    module Selector
      def self.included(base)
        base.send(:include, NIO::Selector::Selectables)
      end
    end
  end
end