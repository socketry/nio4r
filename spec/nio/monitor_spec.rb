require 'spec_helper'

describe NIO::Monitor do
  let :readable do
    reader, writer = IO.pipe
    writer << "have some data"
    reader
  end

  let :selector do
    NIO::Selector.new
  end

  # Monitors are created by registering IO objects or channels with a selector
  subject { selector.register(readable, :r) }

  it "knows its interests" do
    subject.interests.should == :r
  end

  it "stores arbitrary values" do
    subject.value = 42
    subject.value.should == 42
  end

  it "knows what IO objects are ready for" do
    # Perhaps let bindings are just confusing me but they're not producing
    # what I want. Manually doing the setup here does
    # FIXME: Hey RSpec wizards! Fix this!
    reader, writer = IO.pipe
    writer << "loldata"
    selector = NIO::Selector.new
    subject = selector.register(reader, :r)

    # Here's where the spec really begins
    selector.select(1).should include(subject)
    subject.readiness.should == :r
    subject.should be_readable
  end

  it "closes" do
    subject.should_not be_closed
    subject.close
    subject.should be_closed
  end
end
