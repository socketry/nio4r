require 'spec_helper'

describe NIO::Selector do
  it "monitors IO objects" do
    pipe, _ = IO.pipe
    
    monitor = subject.register(pipe, :r)
    monitor.should be_a NIO::Monitor
  end
end