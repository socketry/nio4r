require 'spec_helper'

describe NIO::Channel do
  it "constructs channels from IO objects" do
    channel = NIO::Channel.new(STDIN)
    channel.should be_a NIO::Channel
  end
  
  it "knows blocking modes for channels" do
    pipe, _ = IO.pipe
    channel = pipe.channel
    channel.should be_blocking
  end
end