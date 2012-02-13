#!/usr/bin/env ruby

$:.push File.expand_path('../../lib', __FILE__)
require 'nio'
require 'socket'

class EchoServer
  def initialize(host, port)
    @selector = NIO::Selector.new

    puts "Listening on #{host}:#{port}"
    @server = TCPServer.new(host, port)

    monitor = @selector.register(@server, :r)
    monitor.value = proc { accept }
  end

  def run
    while true
      @selector.select { |monitor| monitor.value.call(monitor) }
    end
  end

  def accept
    socket = @server.accept
    _, port, host = socket.peeraddr
    puts "*** #{host}:#{port} connected"

    monitor = @selector.register(socket, :r)
    monitor.value = proc { read(socket) }
  end

  def read(socket)
    data = socket.read_nonblock(4096)
    socket.write_nonblock(data)
  rescue EOFError
    _, port, host = socket.peeraddr
    puts "*** #{host}:#{port} disconnected"

    @selector.deregister(socket)
    socket.close
  end
end

if $0 == __FILE__
  EchoServer.new("localhost", 1234).run
end
