require 'spec_helper'

describe NIO::Selector do
  it "monitors IO objects" do
    pipe, _ = IO.pipe
    
    monitor = subject.register(pipe, :r)
    monitor.should be_a NIO::Monitor
  end
  
  it "selects objects for readiness" do
    unready_pipe, _ = IO.pipe
    ready_pipe, ready_writer = IO.pipe
    
    # Give ready_pipe some data so it's ready
    ready_writer << "hi there"
    
    unready_monitor = subject.register(unready_pipe, :r)
    ready_monitor   = subject.register(ready_pipe, :r)
    
    ready_monitors = subject.select
    ready_monitors.should include ready_monitor
    ready_monitors.should_not include unready_monitor
  end
end