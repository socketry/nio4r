require 'spec_helper'

describe TCPSocket do
  port_offset = 0
  let(:tcp_port) { 12345 + (port_offset += 1) }

  let :readable_subject do
    server = TCPServer.new("localhost", tcp_port)
    sock = TCPSocket.open("localhost", tcp_port)
    peer = server.accept
    peer << "data"
    sock
  end

  let :unreadable_subject do
    TCPServer.new("localhost", tcp_port)
    sock = TCPSocket.new("localhost", tcp_port)

    # Sanity check to make sure we actually produced an unreadable socket
    if select([sock], [], [], 0)
      pending "Failed to produce an unreadable socket"
    end

    sock
  end

  let :writable_subject do
    TCPServer.new("localhost", tcp_port)
    TCPSocket.new("localhost", tcp_port)
  end

  let :unwritable_subject do
    server = TCPServer.new("localhost", tcp_port)
    sock = TCPSocket.open("localhost", tcp_port)
    peer = server.accept

    begin
      sock.write_nonblock "X" * 1024
      _, writers = select [], [sock], [], 0
    end while writers and writers.include? sock

    # I think the kernel might manage to drain its buffer a bit even after
    # the socket first goes unwritable. Attempt to sleep past this and then
    # attempt to write again
    sleep 0.1

    # Once more for good measure!
    begin
      sock.write_nonblock "X" * 1024
    rescue Errno::EWOULDBLOCK
    end

    # Sanity check to make sure we actually produced an unwritable socket
    if select([], [sock], [], 0)
      pending "Failed to produce an unwritable socket"
    end

    sock
  end

  let :pair do
    server = TCPServer.new("localhost", tcp_port)
    client = TCPSocket.open("localhost", tcp_port)
    [client, server.accept]
  end

  it_behaves_like "an NIO selectable"
  it_behaves_like "an NIO selectable stream"
  it_behaves_like "an NIO bidirectional stream"

  context :connect do
    it "selects writable when connected" do
      selector = NIO::Selector.new
      server = TCPServer.new('127.0.0.1', tcp_port)

      client = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      monitor = selector.register(client, :w)

      expect do
        client.connect_nonblock Socket.sockaddr_in(tcp_port, '127.0.0.1')
      end.to raise_exception Errno::EINPROGRESS

      selector.select(0).should include monitor
      result = client.getsockopt(::Socket::SOL_SOCKET, ::Socket::SO_ERROR)
      result.unpack('i').first.should be_zero
    end
  end
end
