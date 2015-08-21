require "spec_helper"
require "socket"

RSpec.describe NIO::Monitor do
  port_offset = 0
  let(:tcp_port) { 12_345 + (port_offset += 1) }

  # let(:pipes) { IO.pipe }
  # let(:reader) { pipes.first }
  # let(:writer) { pipes.last }

  let(:reader) { TCPServer.new("localhost", tcp_port) }
  let(:writer) { Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0) }

  let(:selector) { NIO::Selector.new }

  subject    { selector.register(reader, :r) }
  let(:peer) { selector.register(writer, :rw) }
  after      { selector.close }

  # in jruby these closes seems like not working properly
  after      { reader.close }
  after      { writer.close }

  it "knows its interests" do
    expect(subject.interests).to eq(:r)
    expect(peer.interests).to eq(:rw)
  end

  it "changes the interest set" do
    expect(peer.interests).not_to eq(:w)
    peer.interests = :w
    expect(peer.interests).to eq(:w)
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

  pending "knows what operations IO objects are ready for" do
    # For whatever odd reason this breaks unless we eagerly evaluate subject
    reader_monitor = subject
    writer_monitor = peer

    selected = selector.select(0)
    expect(selected).not_to include(reader_monitor)
    expect(selected).to include(writer_monitor)

    expect(writer_monitor.readiness).to eq(:rw)
    # expect(writer_monitor).not_to be_readable
    expect(writer_monitor).to be_writable

    reader_monitor.interests = :rw

    # Using TCPSocket and Server to Write takes time but not closes
    reader.puts "This is a test"

    selected = selector.select(0)
    expect(selected).to include(reader_monitor)

    expect(reader_monitor.readiness).to eq(:r)
    expect(reader_monitor).to be_readable
    expect(reader_monitor).not_to be_writable
  end

  it "Changes the interest_set on the go uses TCP Socket" do
    client = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    monitor = selector.register(client, :r)
    expect(monitor.interests).to eq(:r)
    monitor.interests = :w
    expect(monitor.interests).to eq(:w)
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

  it "changes the interest set after monitor closed" do
    # check for changing the interests on the go after closed expected to fail
    expect(subject.interests).not_to eq(:rw)
    subject.close # forced shutdown
    expect { subject.interests = :rw }.to raise_error(TypeError)
  end
end
