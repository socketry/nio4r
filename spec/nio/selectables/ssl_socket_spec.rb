require 'spec_helper'
require 'openssl'

# SSL is only supported on Ruby 1.9+
if RUBY_VERSION > "1.9.0"
  describe OpenSSL::SSL::SSLSocket do
    let(:tcp_port) { 34567 }

    let(:ssl_key) { OpenSSL::PKey::RSA.new(1024) }

    let(:ssl_cert) do
      name = OpenSSL::X509::Name.new([%w[CN localhost]])
      OpenSSL::X509::Certificate.new.tap do |cert|
        cert.version = 2
        cert.serial = 1
        cert.issuer = name
        cert.subject = name
        cert.not_before = Time.now
        cert.not_after = Time.now + (365 * 24 *60 *60)
        cert.public_key = ssl_key.public_key

        cert.sign(ssl_key, OpenSSL::Digest::SHA1.new)
      end
    end

    let(:ssl_server_context) do
      OpenSSL::SSL::SSLContext.new.tap do |ctx|
        ctx.cert = ssl_cert
        ctx.key = ssl_key
      end
    end

    let :readable_subject do
      server = TCPServer.new("localhost", tcp_port)
      client = TCPSocket.open("localhost", tcp_port)
      peer = server.accept

      speer = OpenSSL::SSL::SSLSocket.new(peer, ssl_server_context)
      speer.sync_close = true

      sclient = OpenSSL::SSL::SSLSocket.new(client)
      sclient.sync_close = true

      # SSLSocket#connect and #accept are blocking calls.
      Thread.new { sclient.connect }

      speer.accept
      speer << "data"

      sclient
    end

    let :unreadable_subject do
      server = TCPServer.new("localhost", tcp_port + 1)
      client = TCPSocket.new("localhost", tcp_port + 1)
      peer = server.accept

      speer = OpenSSL::SSL::SSLSocket.new(peer, ssl_server_context)
      speer.sync_close = true

      sclient = OpenSSL::SSL::SSLSocket.new(client)
      sclient.sync_close = true

      # SSLSocket#connect and #accept are blocking calls.
      Thread.new { sclient.connect }

      # Sanity check to make sure we actually produced an unreadable socket
      if select([sclient], [], [], 0)
        pending "Failed to produce an unreadable socket"
      end

      sclient
    end

    let :writable_subject do
      server = TCPServer.new("localhost", tcp_port + 2)
      client = TCPSocket.new("localhost", tcp_port + 2)
      peer = server.accept

      speer = OpenSSL::SSL::SSLSocket.new(peer, ssl_server_context)
      speer.sync_close = true

      sclient = OpenSSL::SSL::SSLSocket.new(client)
      sclient.sync_close = true

      # SSLSocket#connect and #accept are blocking calls.
      Thread.new { sclient.connect }

      speer.accept

      sclient
    end

    let :unwritable_subject do
      server = TCPServer.new("localhost", tcp_port + 3)
      client = TCPSocket.open("localhost", tcp_port + 3)
      peer = server.accept

      speer = OpenSSL::SSL::SSLSocket.new(peer, ssl_server_context)
      speer.sync_close = true

      sclient = OpenSSL::SSL::SSLSocket.new(client)
      sclient.sync_close = true

      # SSLSocket#connect and #accept are blocking calls.
      Thread.new { sclient.connect }

      speer.accept

      begin
        _, writers = select [], [sclient], [], 0
        count = sclient.write_nonblock "X" * 1024
        count.should_not == 0
      rescue IO::WaitReadable, IO::WaitWritable
        pending "SSL will report writable but not accept writes"
        raise if(writers.include? sclient)
      end while writers and writers.include? sclient

      # I think the kernel might manage to drain its buffer a bit even after
      # the socket first goes unwritable. Attempt to sleep past this and then
      # attempt to write again
      sleep 0.1

      # Once more for good measure!
      begin
#        sclient.write_nonblock "X" * 1024
        loop { sclient.write_nonblock "X" * 1024 }
      rescue OpenSSL::SSL::SSLError
      end

      # Sanity check to make sure we actually produced an unwritable socket
#      if select([], [sclient], [], 0)
#        pending "Failed to produce an unwritable socket"
#      end

      sclient
    end

    let :pair do
      pending "figure out why newly created sockets are selecting readable immediately"

      server = TCPServer.new("localhost", tcp_port + 4)
      client = TCPSocket.open("localhost", tcp_port + 4)
      peer = server.accept

      speer = OpenSSL::SSL::SSLSocket.new(peer, ssl_server_context)
      speer.sync_close = true

      sclient = OpenSSL::SSL::SSLSocket.new(client)
      sclient.sync_close = true

      # SSLSocket#connect and #accept are blocking calls.
      Thread.new { sclient.connect }

      [sclient, speer.accept]
    end

    it_behaves_like "an NIO selectable"
    it_behaves_like "an NIO selectable stream"
  end
end