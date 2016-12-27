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

  describe "#position" do
    it "defaults to zero" do
      expect(bytebuffer.position).to be_zero
    end
  end

  describe "#limit" do
    it "defaults to the buffer's capacity" do
      expect(bytebuffer.limit).to eq(capacity)
    end
  end

  describe "#capacity" do
    it "has the requested capacity" do
      expect(bytebuffer.capacity).to eql(capacity)
    end
  end

  describe "#remaining" do
    it "calculates the number of bytes remaining" do
      expect(bytebuffer.remaining).to eql(capacity)
      bytebuffer << example_string
      expect(bytebuffer.remaining).to eql(capacity - example_string.length)
    end
  end

  describe "#get" do
    it "reads zeroes from a newly initialized buffer" do
      expect(bytebuffer.get(capacity)).to eq("\0" * capacity)
    end

    it "advances position as data is read" do
      bytebuffer << "First"
      bytebuffer << "Second"
      bytebuffer << "Third"
      bytebuffer.flip

      expect(bytebuffer.position).to eql(0)
      expect(bytebuffer.get(10)).to eql "FirstSecon"
      expect(bytebuffer.position).to eql(10)
    end

    it "raises NIO::ByteBuffer::UnderflowError if there is not enough data in the buffer" do
      bytebuffer << example_string
      bytebuffer.flip

      expect { bytebuffer.get(example_string.length + 1) }.to raise_error(NIO::ByteBuffer::UnderflowError)
      expect(bytebuffer.get(example_string.length)).to eq(example_string)
    end
  end

  describe "#<<" do
    it "adds strings to the buffer" do
      bytebuffer << example_string
      expect(bytebuffer.position).to eql(example_string.length)
      expect(bytebuffer.limit).to eql(capacity)
    end

    it "raises NIO::ByteBuffer::OverflowError if the buffer is full" do
      bytebuffer << "X" * (capacity - 1)
      expect { bytebuffer << "X" }.not_to raise_error
      expect { bytebuffer << "X" }.to raise_error(NIO::ByteBuffer::OverflowError)
    end
  end

  describe "#flip" do
    it "flips the bytebuffer" do
      bytebuffer << example_string
      expect(bytebuffer.position).to eql(example_string.length)

      bytebuffer.flip

      expect(bytebuffer.position).to eql(0)
      expect(bytebuffer.get(example_string.length)).to eql(example_string)
    end

    it "sets remaining to the previous position" do
      bytebuffer << example_string
      previous_position = bytebuffer.position
      expect(bytebuffer.remaining).to eql(capacity - previous_position)

      bytebuffer.flip
      expect(bytebuffer.remaining).to eql(previous_position)
    end

    it "sets limit to the previous position" do
      bytebuffer << example_string
      expect(bytebuffer.limit).to eql(capacity)

      previous_position = bytebuffer.position
      bytebuffer.flip
      expect(bytebuffer.limit).to eql(previous_position)
    end
  end

  describe "#rewind" do
    pending "rewinds the buffer"
  end

  describe "#clear" do
    it "clears the buffer" do
      bytebuffer << example_string
      bytebuffer.clear

      expect(bytebuffer.remaining).to eql(capacity)
    end
  end
end
