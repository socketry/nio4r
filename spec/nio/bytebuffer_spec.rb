require "spec_helper"

RSpec.describe NIO::ByteBuffer do
  let(:capacity)       { 256 }
  let(:example_string) { "Testing 1 2 3..." }

  subject(:bytebuffer) { described_class.new(capacity) }

  describe "#initialize" do
    it "raises TypeError if given a bogus argument" do
      expect { described_class.new(:symbols_are_bogus) }.to raise_error(TypeError)
    end
  end

  describe "#capacity" do
    it "has the requested capacity" do
      expect(bytebuffer.capacity).to eql(capacity)
    end
  end

  describe "#remaining" do
    it "has the correct number of bytes remaining" do
      expect(bytebuffer.remaining).to eql(capacity)
    end
  end

  describe "#get" do
    it "gets the content of the bytebuffer" do
      bytebuffer << example_string
      bytebuffer.flip
      expect(bytebuffer.get).to eql(example_string)
    end
  end

  describe "#<<" do
    it "adds strings to the buffer" do
      bytebuffer << example_string
      expect(bytebuffer.remaining).to eql(capacity - example_string.length)
    end

    it "raises NIO::ByteBuffer::OverflowError if the buffer is full" do
      bytebuffer << "X" * (capacity - 1)
      expect { bytebuffer << "X" }.not_to raise_error
      expect { bytebuffer << "X" }.to raise_error(NIO::ByteBuffer::OverflowError)
    end
  end

  describe "#read_next" do
    it "reads the content added" do
      bytebuffer << "First"
      bytebuffer << "Second"
      bytebuffer << "Third"
      bytebuffer.flip

      expect(bytebuffer.read_next(10)).to eql "FirstSecon"
    end
  end

  describe "#rewind" do
    pending "rewinds the buffer"
  end

  describe "#compact" do
    it "compacts the buffer" do
      skip # TODO: debug problems on Ruby 2.4
      bytebuffer << "Test"
      bytebuffer << " Text"
      bytebuffer << "Dumb"
      bytebuffer.flip
      bytebuffer.read_next 5
      bytebuffer.compact
      bytebuffer << " RRMARTIN"
      bytebuffer.flip
      expect(bytebuffer.get).to eql("TextDumb RRMARTIN")
    end
  end

  describe "#flip" do
    it "flips the bytebuffer" do
      bytebuffer << example_string
      bytebuffer.flip
      expect(bytebuffer.get).to eql(example_string)
    end
  end

  describe "#clear" do
    it "clears the buffer" do
      bytebuffer << example_string
      bytebuffer.clear

      expect(bytebuffer.remaining).to eql(capacity)
    end
  end
end
