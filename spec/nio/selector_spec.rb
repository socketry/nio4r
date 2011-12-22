require 'spec_helper'

describe NIO::Selector do
  context "register" do
    it "monitors IO objects" do
      pipe, _ = IO.pipe

      monitor = subject.register(pipe, :r)
      monitor.should be_a NIO::Monitor
    end
  
    it "raises ArgumentError if asked to monitor a readable for writing" do
      readable, _ = IO.pipe
      expect { subject.register(readable, :w) }.to raise_exception(ArgumentError)
    end
  end

  context "IO object support" do
    context "pipes" do
      it "selects for read readiness" do
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

    context "TCPSockets" do
      it "selects for read readiness" do
        port = 12345
        server = TCPServer.new("localhost", port)

        ready_socket = TCPSocket.open("localhost", port)
        ready_writer = server.accept

        # Give ready_socket some data so it's ready
        ready_writer << "hi there"

        unready_socket = TCPSocket.open("localhost", port)

        unready_monitor = subject.register(unready_socket, :r)
        ready_monitor   = subject.register(ready_socket, :r)

        ready_monitors = subject.select
        ready_monitors.should include ready_monitor
        ready_monitors.should_not include unready_monitor
      end
    end

    context "UDPSockets" do
      it "selects for read readiness" do
        port = 23456

        ready_socket = UDPSocket.new
        ready_socket.bind('localhost', port)

        ready_writer = UDPSocket.new
        ready_writer.send("hi there", 0, 'localhost', port)

        unready_socket = UDPSocket.new
        unready_socket.bind('localhost', port + 1)

        unready_monitor = subject.register(unready_socket, :r)
        ready_monitor   = subject.register(ready_socket, :r)

        ready_monitors = subject.select
        ready_monitors.should include ready_monitor
        ready_monitors.should_not include unready_monitor
      end
    end
  end
end
