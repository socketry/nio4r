require 'spec_helper'

describe NIO::Selector do
  context "register" do
    it "monitors IO objects" do
      pipe, _ = IO.pipe

      monitor = subject.register(pipe, :r)
      monitor.should be_a NIO::Monitor
    end
  end

  context "select" do
    it "waits for a timeout when selecting" do
      reader, writer = IO.pipe
      monitor = subject.register(reader, :r)

      payload = "hi there"
      writer << payload

      timeout = 0.1
      started_at = Time.now
      subject.select(timeout).should include monitor
      (Time.now - started_at).should be_within(0.01).of(0)
      reader.read_nonblock(payload.size)

      started_at = Time.now
      subject.select(timeout).should == []
      (Time.now - started_at).should be_within(0.01).of(timeout)
    end

    it "wakes up if signaled to from another thread" do
      pipe, _ = IO.pipe
      subject.register(pipe, :r)

      thread = Thread.new do
        started_at = Time.now
        subject.select
        Time.now - started_at
      end

      timeout = 0.1
      sleep timeout
      subject.wakeup

      thread.value.should be_within(0.01).of(timeout)
    end
  end

  it "closes" do
    subject.close
    subject.should be_closed
  end

  context "selectables" do
    shared_context "an NIO selectable" do
      it "selects for read readiness" do
        waiting_monitor = subject.register(unreadable_subject, :r)
        ready_monitor   = subject.register(readable_subject, :r)

        ready_monitors = subject.select
        ready_monitors.should include ready_monitor
        ready_monitors.should_not include waiting_monitor
      end

      it "selects for write readiness" do
        waiting_monitor = subject.register(unwritable_subject, :w)
        ready_monitor   = subject.register(writable_subject, :w)

        ready_monitors = subject.select(0.1)

        ready_monitors.should include ready_monitor
        ready_monitors.should_not include waiting_monitor
      end
    end

    context "IO.pipe" do
      let :readable_subject do
        pipe, peer = IO.pipe
        peer << "data"
        pipe
      end

      let :unreadable_subject do
        pipe, _ = IO.pipe
        pipe
      end

      let :writable_subject do
        _, pipe = IO.pipe
        pipe
      end

      let :unwritable_subject do
        _, pipe = IO.pipe

        begin
          pipe.write_nonblock "JUNK IN THE TUBES"
          _, writers = select [], [pipe], [], 0
        rescue Errno::EPIPE
          break
        end while writers and writers.include? pipe

        pipe
      end

      it_behaves_like "an NIO selectable"
    end

    context TCPSocket do
      let(:tcp_port) { 12345 }

      let :readable_subject do
        server = TCPServer.new("localhost", tcp_port)
        sock = TCPSocket.open("localhost", tcp_port)
        peer = server.accept
        peer << "data"
        sock
      end

      let :unreadable_subject do
        TCPServer.new("localhost", tcp_port + 1)
        TCPSocket.open("localhost", tcp_port + 1)
      end

      let :writable_subject do
        TCPServer.new("localhost", tcp_port + 2)
        TCPSocket.open("localhost", tcp_port + 2)
      end

      let :unwritable_subject do
        server = TCPServer.new("localhost", tcp_port + 3)
        sock = TCPSocket.open("localhost", tcp_port + 3)
        peer = server.accept

        begin
          sock.write "JUNK IN THE TUBES"
          _, writers = select [], [sock], [], 0
        rescue Errno::EPIPE
        end while writers and writers.include? sock

        sock
      end

      it_behaves_like "an NIO selectable"
    end

    context UDPSocket do
      let(:udp_port) { 23456 }

      let :readable_subject do
        sock = UDPSocket.new
        sock.bind('localhost', udp_port)

        peer = UDPSocket.new
        peer.send("hi there", 0, 'localhost', udp_port)

        sock
      end

      let :unreadable_subject do
        sock = UDPSocket.new
        sock.bind('localhost', udp_port + 1)
        sock
      end

      let :writable_subject do
        pending "come up with a writable UDPSocket example"
      end

      let :unwritable_subject do
        pending "come up with a UDPSocket that's blocked on writing"
      end

      it_behaves_like "an NIO selectable"
    end
  end
end
