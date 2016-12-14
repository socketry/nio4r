require 'spec_helper'
require 'tmpdir'

describe UNIXSocket do
  socket_index = 0
  let(:socket_path) do
    path = File.join(Dir.tmpdir, "nio4r_socket_#{socket_index += 1}")
    File.delete(path) if File.exists?(path)
    path
  end
 
  let :readable_subject do
    server = UNIXServer.new(socket_path)
    sock   = UNIXSocket.new(socket_path)
    peer   = server.accept

    peer << "data"
    sock
  end

  let :unreadable_subject do
    server = UNIXServer.new(socket_path)
    sock   = UNIXSocket.new(socket_path)

    # Sanity check to make sure we actually produced an unreadable socket
    if select([sock], [], [], 0)
      pending "Failed to produce an unreadable socket"
    end

    sock
  end

  let :writable_subject do
    UNIXServer.new(socket_path)
    UNIXSocket.new(socket_path)
  end

  let :unwritable_subject do
    server = UNIXServer.new(socket_path)
    sock   = UNIXSocket.new(socket_path)
    peer   = server.accept

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
    server = UNIXServer.new(socket_path)
    client = UNIXSocket.open(socket_path)
    [client, server.accept]
  end

  it_behaves_like "an NIO selectable"
  it_behaves_like "an NIO selectable stream"
  it_behaves_like "an NIO bidirectional stream"
end
