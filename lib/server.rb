# frozen_string_literal: true

require "socket"
require_relative "./command"

module Mule
  class Server
    CRLF = "\r\n"

    attr_reader :workers

    def initialize(port = 21, workers = 4)
      @control_socket = TCPServer.new(port)
      @workers = workers
      trap(:INT) { exit }
    end

    def gets
      @client.gets(CRLF)
    end

    def respond(message)
      @client.write(message)
      @client.write(CRLF)
    end

    def run
      child_pids = []
      workers.times { child_pids << spawn_child }

      trap(:INT) do
        child_pids.each do |cpid|
          begin
            Process.kill(:INT, cpid)
          rescue Errno::ESRCH
          end
        end

        exit
      end

      loop do
        pid = Process.wait
        $stderr.puts "Process #{pid} quit unexpectedly"

        child_pids.delete(pid)
        child_pids << spawn_child
      end
    end

    private
      def spawn_child
        fork do
          @client = @control_socket.accept
          respond "220 OHAI"

          handler = Command.new(self)

          loop do
            request = gets

            if request
              respond handler.execute(request)
            else
              @client.close
              break
            end
          end
        end
      end
  end
end

server = Mule::Server.new(4481)
server.run
