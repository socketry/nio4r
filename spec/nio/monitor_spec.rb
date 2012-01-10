require 'spec_helper'

describe NIO::Monitor do
  let(:pipes) { IO.pipe }
  let(:reader) { pipes.first }
  let(:writer) { pipes.last }
  let(:selector) { NIO::Selector.new }
  subject { selector.register(reader, :r) }
  after   { selector.close }

  it "knows its interests" do
    subject.interests.should == :r
  end

  it "stores arbitrary values" do
    subject.value = 42
    subject.value.should == 42
  end

  it "knows what operations IO objects are ready for" do
    # For whatever odd reason this breaks unless we eagerly evaluate subject
    monitor = subject
    writer << "loldata"

    selector.select(1).should include(monitor)
    monitor.readiness.should == :r
    monitor.should be_readable
  end

  it "closes" do
    subject.should_not be_closed
    subject.close
    subject.should be_closed
  end
end
