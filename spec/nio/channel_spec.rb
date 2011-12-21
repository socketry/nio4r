require 'spec_helper'

describe NIO::Channel do
  context "blocking modes" do
    before :each do
      @pipe, _ = IO.pipe
      @channel = @pipe.channel
    end

    it "knows blocking modes for channels" do
      @channel.should be_blocking
    end

    it "sets blocking modes for channels" do
      @channel.should be_blocking
      @channel.blocking = false
      @channel.should_not be_blocking
    end

    it "raises TypeError if the blocking mode is not a boolean" do
      expect { @channel.blocking = :trollsymbol }.to raise_exception TypeError
    end
  end
end
