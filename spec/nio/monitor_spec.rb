require 'spec_helper'

describe NIO::Monitor do
  let(:pipes) { IO.pipe }
  let(:reader) { pipes.first }
  let(:writer) { pipes.last }
  let(:selector) { NIO::Selector.new }

  subject    { selector.register(reader, :r) }
  let(:peer) { selector.register(writer, :rw) }
  after      { selector.close }

  it "knows its interests" do
    subject.interests.should == :r
    peer.interests.should == :rw
  end

  it "knows its IO object" do
    subject.io.should == reader
  end

  it "knows its selector" do
    subject.selector.should == selector
  end

  it "stores arbitrary values" do
    subject.value = 42
    subject.value.should == 42
  end

  it "knows what operations IO objects are ready for" do
    # For whatever odd reason this breaks unless we eagerly evaluate subject
    reader_monitor, writer_monitor = subject, peer

    selected = selector.select(0)
    selected.should_not include(reader_monitor)
    selected.should include(writer_monitor)

    writer_monitor.readiness.should == :w
    writer_monitor.should_not be_readable
    writer_monitor.should be_writable

    writer << "loldata"

    selected = selector.select(0)
    selected.should include(reader_monitor)

    reader_monitor.readiness.should == :r
    reader_monitor.should be_readable
    reader_monitor.should_not be_writable
  end

  it "closes" do
    subject.should_not be_closed
    selector.registered?(reader).should be_true

    subject.close
    subject.should be_closed
    selector.registered?(reader).should be_false
  end
end
