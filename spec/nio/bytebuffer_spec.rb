require "spec_helper"

RSpec.describe NIO::ByteBuffer do
  describe "#Behaviour of ByteBuffer" do
    subject { bytebuffer }

    context "allocates a given size buffer" do
      let(:bytebuffer) { NIO::ByteBuffer.new(256, nil, nil) }

      before :each do
        bytebuffer.clear
      end

      it "Checks the allocation" do
        expect(bytebuffer.capacity).to eql(256)
      end

      it "checks remaining" do
        expect(bytebuffer.remaining).to eql(256)
      end

      it "puts a given string to buffer" do
        bytebuffer << "Song of Ice & Fire"
        expect(bytebuffer.remaining).to eql(238)
      end

      it "reads the content added" do
        bytebuffer << "Test"
        bytebuffer << "Text"
        bytebuffer << "Dumb"
        bytebuffer.flip
        expect(bytebuffer.read_next(5)).to eql "TestT"
      end

      it "rewinds the buffer" do
      end

      it "compacts the buffer" do
        bytebuffer << "Test"
        bytebuffer << " Text"
        bytebuffer << "Dumb"
        bytebuffer.flip
        bytebuffer.read_next 5
        bytebuffer.compact
        bytebuffer << " RRMARTIN"
        bytebuffer.flip
        # expect(bytebuffer.limit?).to eql(10)
        expect(bytebuffer.get).to eql("TextDumb RRMARTIN")
      end

      it "flips the bytebuffer" do
        bytebuffer << "Test"
        bytebuffer.flip
        expect(bytebuffer.get).to eql("Test")
      end

      it "reads the next items" do
        bytebuffer << "John Snow"
        bytebuffer.flip
        bytebuffer.read_next 5
        expect(bytebuffer.read_next(4)).to eql("Snow")
      end

      it "clears the buffer" do
        bytebuffer << "Game of Thrones"
        bytebuffer.clear
        expect(bytebuffer.remaining).to eql(256)
      end

      it "gets the content of the bytebuffer" do
        bytebuffer << "Test"
        bytebuffer.flip
        expect(bytebuffer.get).to eql("Test")
      end
    end
  end
end
