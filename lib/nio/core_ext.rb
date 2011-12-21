class IO
  # Obtain an NIO::Channel for this object
  def channel
    NIO::Channel.new(self)
  end
end