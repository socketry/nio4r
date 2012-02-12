describe "NIO selectables" do
  let(:selector) { NIO::Selector.new }

  shared_context "an NIO selectable" do
    it "selects readable objects" do
      monitor = selector.register(readable_subject, :r)
      selector.select(0).should include monitor
    end

    it "does not select unreadable objects" do
      monitor = selector.register(unreadable_subject, :r)
      selector.select(0).should be_nil
    end

    it "selects writable objects" do
      monitor = selector.register(writable_subject, :w)
      selector.select(0).should include monitor
    end

    it "does not select unwritable objects" do
      monitor = selector.register(unwritable_subject, :w)
      selector.select(0).should be_nil
    end
  end

  shared_context "an NIO selectable stream" do
    let(:stream) { pair.first }
    let(:peer)   { pair.last }

    it "selects readable when the other end closes" do
      monitor = selector.register(stream, :r)
      selector.select(0).should be_nil

      peer.close
      selector.select(0).should include monitor
    end
  end

  describe "IO.pipe" do
    let(:pair) { IO.pipe }

    let :unreadable_subject do pair.first end
    let :readable_subject do
      pipe, peer = pair
      peer << "data"
      pipe
    end

    let :writable_subject do pair.last end
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

  describe TCPSocket do
    let(:tcp_port) { 12345 }

    let :readable_subject do
      server = TCPServer.new("localhost", tcp_port)
      sock = TCPSocket.open("localhost", tcp_port)
      peer = server.accept
      peer << "data"
      sock
    end

    let :unreadable_subject do
      if defined?(JRUBY_VERSION) and ENV['TRAVIS']
        pending "This is sporadically showing up readable on JRuby in CI"
      else
        TCPServer.new("localhost", tcp_port + 1)
        TCPSocket.open("localhost", tcp_port + 1)
      end
    end

    let :writable_subject do
      TCPServer.new("localhost", tcp_port + 2)
      TCPSocket.open("localhost", tcp_port + 2)
    end

    let :unwritable_subject do
      server = TCPServer.new("localhost", tcp_port + 3)
      sock = TCPSocket.open("localhost", tcp_port + 3)
      peer = server.accept

      if defined? JRUBY_VERSION
        # The implementation below seems more reliable, but triggers a JRuby
        # bug. See: http://jira.codehaus.org/browse/JRUBY-6442
        begin
          sock.write_nonblock "JUNK IN THE TUBES"
          _, writers = select [], [sock], [], 0
        end while writers and writers.include? sock
      else
        loop do
          begin
            sock.write_nonblock("JUNK IN THE TUBES")
          rescue Errno::EWOULDBLOCK
            break
          end
        end
      end

      # A few more for good measure!
      3.times do
        begin
          sock.write_nonblock "JUNK IN THE TUBES"
        rescue Errno::EWOULDBLOCK
        end
      end

      # Sanity check to make sure we actually produced an unwritable socket
      if select([], [sock], [], 0)
        pending "Failed to produce an unwritable socket"
      end

      sock
    end

    let :pair do
      server = TCPServer.new("localhost", tcp_port + 4)
      client = TCPSocket.open("localhost", tcp_port + 4)
      [client, server.accept]
    end

    it_behaves_like "an NIO selectable"
    it_behaves_like "an NIO selectable stream"

    it "selects writable when connected" do
      server = TCPServer.new('127.0.0.1', tcp_port + 5)

      client = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      monitor = selector.register(client, :w)

      expect do
        client.connect_nonblock Socket.sockaddr_in(tcp_port + 5, '127.0.0.1')
      end.to raise_exception Errno::EINPROGRESS

      selector.select(0).should include monitor
      result = client.getsockopt(::Socket::SOL_SOCKET, ::Socket::SO_ERROR)
      result.unpack('i').first.should be_zero
    end
  end

  describe UDPSocket do
    let(:udp_port) { 23456 }

    let :readable_subject do
      sock = UDPSocket.new
      sock.bind('localhost', udp_port)

      peer = UDPSocket.new
      peer.send("hi there", 0, 'localhost', udp_port)

      sock
    end

    let :unreadable_subject do
      sock = UDPSocket.new
      sock.bind('localhost', udp_port + 1)
      sock
    end

    let :writable_subject do
      pending "come up with a writable UDPSocket example"
    end

    let :unwritable_subject do
      pending "come up with a UDPSocket that's blocked on writing"
    end

    it_behaves_like "an NIO selectable"
  end
end
