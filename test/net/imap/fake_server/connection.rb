# frozen_string_literal: true

class Net::IMAP::FakeServer
  # > "Connection" refers to the entire sequence of client/server interaction
  # > from the initial establishment of the network connection until its
  # > termination.
  # --- https://www.rfc-editor.org/rfc/rfc9051#name-conventions-used-in-this-do
  class Connection
    attr_reader :config, :state

    def initialize(server, tcp_socket:)
      @config = server.config
      @socket = Socket.new tcp_socket, config: config
      @state  = ConnectionState.new socket: socket, config: config
      @reader = CommandReader.new  socket
      @writer = ResponseWriter.new socket, config: config, state: state
      @router = CommandRouter.new  writer, config: config, state: state
    end

    def commands; state.commands end
    def on(...) router.on(...) end

    def run
      writer.greeting
      router << reader.get_command until state.logout?
    ensure
      close
    end

    def close
      unless state.logout?
        state.logout
        writer.bye
      end
      socket&.close unless socket&.closed?
    end

    private

    attr_reader :socket, :reader, :writer, :router

  end
end
