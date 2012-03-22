require 'spec_helper'

describe "IO.pipe" do
  let(:pair) { IO.pipe }

  let :unreadable_subject do
    pair.first
  end
  let :readable_subject do
    pipe, peer = pair
    peer << "data"
    pipe
  end

  let :writable_subject do
    pair.last
  end
  let :unwritable_subject do
    reader, pipe = IO.pipe

    begin
      pipe.write_nonblock "JUNK IN THE TUBES"
      _, writers = select [], [pipe], [], 0
    rescue Errno::EPIPE
      break
    end while writers and writers.include? pipe

    pipe
  end

  it_behaves_like "an NIO selectable"
  it_behaves_like "an NIO selectable stream"
end
