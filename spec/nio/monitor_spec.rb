require "spec_helper"

RSpec.describe NIO::Monitor do
  let(:pipes) { IO.pipe }
  let(:reader) { pipes.first }
  let(:writer) { pipes.last }
  let(:selector) { NIO::Selector.new }

  subject    { selector.register(reader, :r) }
  let(:peer) { selector.register(writer, :rw) }
  after      { selector.close }

  it "knows its interests" do
    expect(subject.interests).to eq(:r)
    expect(peer.interests).to eq(:rw)
  end

  it "knows its IO object" do
    expect(subject.io).to eq(reader)
  end

  it "knows its selector" do
    expect(subject.selector).to eq(selector)
  end

  it "stores arbitrary values" do
    subject.value = 42
    expect(subject.value).to eq(42)
  end

  it "knows what operations IO objects are ready for" do
    # For whatever odd reason this breaks unless we eagerly evaluate subject
    reader_monitor = subject
    writer_monitor = peer

    selected = selector.select(0)
    expect(selected).not_to include(reader_monitor)
    expect(selected).to include(writer_monitor)

    expect(writer_monitor.readiness).to eq(:w)
    expect(writer_monitor).not_to be_readable
    expect(writer_monitor).to be_writable

    writer << "loldata"

    selected = selector.select(0)
    expect(selected).to include(reader_monitor)

    expect(reader_monitor.readiness).to eq(:r)
    expect(reader_monitor).to be_readable
    expect(reader_monitor).not_to be_writable
  end

  it "closes" do
    expect(subject).not_to be_closed
    expect(selector.registered?(reader)).to be_truthy

    subject.close
    expect(subject).to be_closed
    expect(selector.registered?(reader)).to be_falsey
  end

  it "closes even if the selector has been shutdown" do
    expect(subject).not_to be_closed
    selector.close # forces shutdown
    expect(subject).not_to be_closed
    subject.close
    expect(subject).to be_closed
  end
end
