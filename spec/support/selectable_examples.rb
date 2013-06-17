shared_context "an NIO selectable" do
  let(:selector) { NIO::Selector.new }

  it "selects readable objects" do
    monitor = selector.register(readable_subject, :r)
    ready = selector.select(0)
    ready.should be_an Enumerable
    ready.should include monitor
  end

  it "does not select unreadable objects" do
    monitor = selector.register(unreadable_subject, :r)
    selector.select(0).should be_nil
  end

  it "selects writable objects" do
    monitor = selector.register(writable_subject, :w)
    ready = selector.select(0)
    ready.should be_an Enumerable
    ready.should include monitor
  end

  it "does not select unwritable objects" do
    monitor = selector.register(unwritable_subject, :w)
    selector.select(0).should be_nil
  end
end

shared_context "an NIO selectable stream" do
  let(:selector) { NIO::Selector.new }
  let(:stream)   { pair.first }
  let(:peer)     { pair.last }

  it "selects readable when the other end closes" do
    monitor = selector.register(stream, :r)
    selector.select(0).should be_nil

    peer.close
    #Wait and give the TCP session time to close
    selector.select(0.1).should include monitor
  end
end

shared_context "an NIO bidirectional stream" do
  let(:selector) { NIO::Selector.new }
  let(:stream)   { pair.first }
  let(:peer)     { pair.last }

  it "selects readable and writable" do
    monitor = selector.register(readable_subject, :rw)
    selector.select(0) do |m|
      m.readiness.should == :rw
    end
  end
end
