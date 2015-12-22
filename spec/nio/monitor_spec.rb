require "spec_helper"
require "socket"

RSpec.describe NIO::Monitor do
  let(:example_peers) do
    address   = "127.0.0.1"
    base_port = 12_345
    tries     = 10

    server = tries.times do |n|
      begin
        break TCPServer.new(address, base_port + n)
      rescue Errno::EADDRINUSE
        retry
      end
    end

    fail Errno::EADDRINUSE, "couldn't find an open port" unless server
    client = TCPSocket.new(address, server.addr[1])
    [server, client]
  end

  let(:reader) { example_peers.first }
  let(:writer) { example_peers.last }

  let(:selector) { NIO::Selector.new }

  subject    { selector.register(reader, :r) }
  let(:peer) { selector.register(writer, :rw) }
  after      { selector.close }

  before     { example_peers } # open server and client automatically
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

  it "knows what operations IO objects are ready for" do
    # For whatever odd reason this breaks unless we eagerly evaluate subject
    reader_monitor = subject
    writer_monitor = peer

    selected = selector.select(0)
    expect(selected).to include(writer_monitor)

    expect(writer_monitor.readiness).to eq(:w)
    expect(writer_monitor).not_to be_readable
    expect(writer_monitor).to be_writable

    writer << "testing 1 2 3"

    selected = selector.select(0)
    expect(selected).to include(reader_monitor)

    expect(reader_monitor.readiness).to eq(:r)
    expect(reader_monitor).to be_readable
    expect(reader_monitor).not_to be_writable
  end

  it "changes current interests with #interests=" do
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
