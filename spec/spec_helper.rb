# frozen_string_literal: true

require "coveralls"
Coveralls.wear!

require "rubygems"
require "bundler/setup"
require "nio"
require "support/selectable_examples"

RSpec.configure(&:disable_monkey_patching!)

$current_tcp_port = 10_000

def next_available_tcp_port
  loop do
    $current_tcp_port += 1

    begin
      sock = Timeout.timeout(0.1) { TCPSocket.new("localhost", $current_tcp_port) }
    rescue Errno::ECONNREFUSED
      break $current_tcp_port
    end

    sock.close
  end
end
