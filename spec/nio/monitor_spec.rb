# frozen_string_literal: true

require "spec_helper"
require "socket"

RSpec.describe NIO::Monitor do
  let(:addr) { "localhost" }
  let(:port) { next_available_tcp_port }

  let(:reader) { TCPServer.new(addr, port) }
  let(:writer) { TCPSocket.new(addr, port) }

  let(:selector) { NIO::Selector.new }

  subject(:monitor) { selector.register(reader, :r) }
  subject(:peer)    { selector.register(writer, :rw) }

  before { reader }
  before { writer }
  after  { reader.close }
  after  { writer.close }
  after  { selector.close }

  describe "#interests" do
    it "knows its interests" do
      expect(monitor.interests).to eq(:r)
      expect(peer.interests).to eq(:rw)
    end
  end

  describe "#interests=" do
    it "changes the interest set" do
      expect(peer.interests).not_to eq(:w)
      peer.interests = :w
      expect(peer.interests).to eq(:w)
    end

    it "raises EOFError if interests are changed after the monitor is closed" do
      monitor.close
      expect { monitor.interests = :rw }.to raise_error(EOFError)
    end
  end

  describe "#io" do
    it "knows its IO object" do
      expect(monitor.io).to eq(reader)
    end
  end

  describe "#selector" do
    it "knows its selector" do
      expect(monitor.selector).to eq(selector)
    end
  end

  describe "#value=" do
    it "stores arbitrary values" do
      monitor.value = 42
      expect(monitor.value).to eq(42)
    end
  end

  describe "#readiness" do
    it "knows what operations IO objects are ready for" do
      # For whatever odd reason this breaks unless we eagerly evaluate monitor
      reader_monitor = monitor
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
  end

  describe "#close" do
    it "closes" do
      expect(monitor).not_to be_closed
      expect(selector.registered?(reader)).to be_truthy

      monitor.close
      expect(monitor).to be_closed
      expect(selector.registered?(reader)).to be_falsey
    end

    it "closes even if the selector has been shutdown" do
      expect(monitor).not_to be_closed
      selector.close # forces shutdown
      expect(monitor).not_to be_closed
      monitor.close
      expect(monitor).to be_closed
    end
  end
end
