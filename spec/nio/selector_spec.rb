require 'spec_helper'

# Timeouts should be at least this precise (in seconds) to pass the tests
# Typical precision should be better than this, but if it's worse it will fail
# the tests
TIMEOUT_PRECISION = 0.1

describe NIO::Selector do
  let(:pair)   { IO.pipe }
  let(:reader) { pair.first }
  let(:writer) { pair.last }

  context "register" do
    it "registers IO objects" do
      monitor = subject.register(reader, :r)
      monitor.should_not be_closed
    end

    it "raises TypeError if asked to register non-IO objects" do
      expect { subject.register(42, :r) }.to raise_exception TypeError
    end

    it "raises when asked to register after closing" do
      subject.close
      expect { subject.register(reader, :r) }.to raise_exception IOError
    end
  end

  it "knows which IO objects are registered" do
    subject.register(reader, :r)
    subject.should be_registered(reader)
    subject.should_not be_registered(writer)
  end

  it "deregisters IO objects" do
    subject.register(reader, :r)

    monitor = subject.deregister(reader)
    subject.should_not be_registered(reader)
    monitor.should be_closed
  end

  it "reports if it is empty" do
    subject.should be_empty

    monitor = subject.register(reader, :r)

    subject.should_not be_empty
  end

  # This spec might seem a bit silly, but this actually something the
  # Java NIO API specifically precludes that we need to work around
  it "allows reregistration of the same IO object across select calls" do
    monitor = subject.register(reader, :r)
    writer << "ohai"

    subject.select.should include monitor
    reader.read(4).should == "ohai"
    subject.deregister(reader)

    new_monitor = subject.register(reader, :r)
    writer << "thar"
    subject.select.should include new_monitor
    reader.read(4).should == "thar"
  end

  context "timeouts" do
    it "waits for a timeout when selecting" do
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
      subject.register(reader, :r)

      expect { subject.select(-1) }.to raise_exception(ArgumentError)
    end
  end

  context "wakeup" do
    it "wakes up if signaled to from another thread" do
      subject.register(reader, :r)

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
      writer << "ohai"
      unready, _ = IO.pipe

      reader_monitor  = subject.register(reader, :r)
      unready_monitor = subject.register(unready, :r)

      selected = subject.select(0)
      selected.size.should == 1
      selected.should include reader_monitor
      selected.should_not include unready_monitor
    end

    it "selects closed IO objects" do
      monitor = subject.register(reader, :r)
      subject.select(0).should be_nil

      thread = Thread.new { subject.select }
      Thread.pass while thread.status && thread.status != "sleep"

      writer.close
      selected = thread.value
      selected.should include monitor
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

      readables.should include monitor1
      readables.should include monitor2
      readables.should_not include monitor3
    end
  end

  it "closes" do
    subject.close
    subject.should be_closed
  end
end
