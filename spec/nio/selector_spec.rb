require 'spec_helper'

describe NIO::Selector do
  it "monitors IO objects" do
    reader, writer = IO.pipe
    channel = reader.channel
    channel.blocking = false
    
    monitor = subject.register(channel, :r)
    monitor.should be_a NIO::Monitor
  end
end