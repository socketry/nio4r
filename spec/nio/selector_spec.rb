require 'spec_helper'

# Timeouts should be at least this precise (in seconds) to pass the tests
# Typical precision should be better than this, but if it's worse it will fail
# the tests
TIMEOUT_PRECISION = 0.1

describe NIO::Selector do
  context "register" do
    it "registers IO objects" do
      pipe, _ = IO.pipe

      monitor = subject.register(pipe, :r)
      monitor.should_not be_closed
    end

    it "raises TypeError if asked to register non-IO objects" do
      expect { subject.register(42, :r) }.to raise_exception TypeError
    end
  end

  it "knows which IO objects are registered" do
    reader, writer = IO.pipe
    subject.register(reader, :r)

    subject.should be_registered(reader)
    subject.should_not be_registered(writer)
  end

  it "deregisters IO objects" do
    pipe, _ = IO.pipe

    subject.register(pipe, :r)
    monitor = subject.deregister(pipe)
    subject.should_not be_registered(pipe)
    monitor.should be_closed
  end

  context "timeouts" do
    it "waits for a timeout when selecting" do
      reader, writer = IO.pipe
      monitor = subject.register(reader, :r)

      payload = "hi there"
      writer << payload

      timeout = 0.5
      started_at = Time.now
      subject.select(timeout).should include monitor
      (Time.now - started_at).should be_within(TIMEOUT_PRECISION).of(0)
      reader.read_nonblock(payload.size)

      started_at = Time.now
      subject.select(timeout).should be_nil
      (Time.now - started_at).should be_within(TIMEOUT_PRECISION).of(timeout)
    end

    it "raises ArgumentError if given a negative timeout" do
      reader, _ = IO.pipe
      subject.register(reader, :r)

      expect { subject.select(-1) }.to raise_exception(ArgumentError)
    end
  end

  context "wakeup" do
    it "wakes up if signaled to from another thread" do
      pipe, _ = IO.pipe
      subject.register(pipe, :r)

      thread = Thread.new do
        started_at = Time.now
        subject.select.should be_nil
        Time.now - started_at
      end

      timeout = 0.1
      sleep timeout
      subject.wakeup

      thread.value.should be_within(TIMEOUT_PRECISION).of(timeout)
    end

    it "raises IOError if asked to wake up a closed selector" do
      subject.close
      subject.should be_closed

      expect { subject.wakeup }.to raise_exception IOError
    end
  end

  context "select" do
    it "selects IO objects" do
      readable, writer = IO.pipe
      writer << "ohai"

      unreadable, _ = IO.pipe

      readable_monitor   = subject.register(readable, :r)
      unreadable_monitor = subject.register(unreadable, :r)

      selected = subject.select(0)
      selected.size.should == 1
      selected.should include(readable_monitor)
      selected.should_not include(unreadable_monitor)
    end

    it "iterates across selected objects with a block" do
      readable1, writer = IO.pipe
      writer << "ohai"

      readable2, writer = IO.pipe
      writer << "ohai"

      unreadable, _ = IO.pipe

      monitor1 = subject.register(readable1, :r)
      monitor2 = subject.register(readable2, :r)
      monitor3 = subject.register(unreadable, :r)

      readables = []
      result = subject.select { |monitor| readables << monitor }
      result.should == 2

      readables.should include(monitor1)
      readables.should include(monitor2)
      readables.should_not include(monitor3)
    end
  end

  context "select_each" do
    it "iterates across ready selectables" do
      readable1, writer = IO.pipe
      writer << "ohai"

      readable2, writer = IO.pipe
      writer << "ohai"

      unreadable, _ = IO.pipe

      monitor1 = subject.register(readable1, :r)
      monitor2 = subject.register(readable2, :r)
      monitor3 = subject.register(unreadable, :r)

      readables = []
      subject.select_each { |monitor| readables << monitor }

      readables.should include(monitor1)
      readables.should include(monitor2)
      readables.should_not include(monitor3)
    end

    it "allows new monitors to be registered in the select_each block" do
      server = TCPServer.new("localhost", 10001)

      monitor = subject.register(server, :r)
      connector = TCPSocket.open("localhost", 10001)

      block_fired = false
      subject.select_each do |monitor|
        block_fired = true
        socket = server.accept
        subject.register(socket, :r).should be_a NIO::Monitor
      end

      block_fired.should be_true
    end
  end

  it "closes" do
    subject.close
    subject.should be_closed
  end
end
