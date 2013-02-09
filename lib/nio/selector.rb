require 'monitor'

module NIO
  class Selector
    
    def self.threadsafe!
      def initialize(*args)
        @lock = ::Monitor.new
        super
      end
      lock_methods(:select, :register, :deregister, :registered?, :close, :closed?, :empty?)
    end
    
    def self.lock_methods(*methods)
      methods.each do |m|
        if(method_defined? m)
          nolock = :"#{m}_without_lock"
          alias_method nolock, m
          define_method m do |*args, &block|
            @lock.synchronize do
              send nolock, *args, &block
            end
          end
        else #This case the method is on a superclass/module
          define_method m do |*args, &block|
            @lock.synchronize do
              super(*args, &block)
            end
          end
        end
      end
    end
  end
end