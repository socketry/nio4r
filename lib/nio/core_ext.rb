# This lock must be acquired to lazily initialize any IO object's channel
$IO_CHANNEL_LOCK = Mutex.new

class IO
  # Obtain an NIO::Channel for this object
  def channel
    @nio4r_channel ||= $IO_CHANNEL_LOCK.synchronize do
      # We can only do this sort of lazy memoization safely with the lock held
      # so if it failed the first time retry now that we've acquired the lock
      @nio4r_channel ||= NIO::Channel.new(self)
    end
  end
end