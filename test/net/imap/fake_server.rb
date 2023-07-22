# frozen_string_literal: true

require "net/imap"

# NOTE: API is experimental and may change without deprecation or warning.
#
# FakeServer is simple fake IMAP server that is used for testing Net::IMAP.  It
# contains simple implementations of many IMAP commands and allows customization
# of server responses.  This allow tests to assume a more-or-less "normal" IMAP
# server implementation, so as to focus on what's important for what's being
# tested without needing to fuss over the details of a TCPServer script.
#
# Although the API is not (yet) stable, Net::IMAP::FakeServer is also intended
# to be useful for testing libraries and applications which themselves use
# Net::IMAP.
#
# ## Limitations
#
# FakeServer cannot be a complete replacement for exploratory testing or
# integration testing with actual IMAP servers.  Simple default behaviors will
# be provided for many commands, and tests may simulate specific server
# responses by assigning handlers (using #on).
#
# And FakeServer is significantly more complex than simply creating a socket IO
# script in a separate thread.  This complexity may obscure the focus of some
# tests or make it more difficult to debug them.  Use with discretion.
#
# Currently, the server will shutdown after a single connection has been
# accepted and closed.  This may change in the future, but only if tests can be
# simplified or made significantly faster by allowing multiple connections to
# the same TCPServer.
#
class Net::IMAP::FakeServer
  dir = "#{__dir__}/fake_server"
  autoload :Command,               "#{dir}/command"
  autoload :CommandReader,         "#{dir}/command_reader"
  autoload :CommandRouter,         "#{dir}/command_router"
  autoload :CommandResponseWriter, "#{dir}/command_response_writer"
  autoload :Configuration,         "#{dir}/configuration"
  autoload :Connection,            "#{dir}/connection"
  autoload :ConnectionState,       "#{dir}/connection_state"
  autoload :ResponseWriter,        "#{dir}/response_writer"
  autoload :Socket,                "#{dir}/socket"
  autoload :Session,               "#{dir}/session"
  autoload :TestHelper,            "#{dir}/test_helper"

  # Returns the server's FakeServer::Configuration
  attr_reader :config

  # All arguments to FakeServer#initialize are forwarded to
  # FakeServer::Configuration#initialize, to define the FakeServer#config.
  #
  # The server will immediately bind to a port, so any non-default +hostname+
  # and +port+ must be specified as parameters.  Changing them after creating
  # the server will have no effect.  The default values are <tt>hostname:
  # "localhost", port: 0</tt>, which binds to a random port.  Use
  # FakeServer#port to learn which port was chosen.
  #
  # The server does not accept any incoming connections until #run is called.
  def initialize(...)
    @config     = Configuration.new(...)
    @tcp_server = TCPServer.new(config.hostname, config.port)
    @connection = nil
  end

  def host; tcp_server.addr[2] end
  def port; tcp_server.addr[1] end

  # Accept a client connection and run a server loop to handle incoming
  # commands.  #run will block until that connection has closed, and must be
  # called in a different Thread (or Fiber) from the client connection.
  def run
    Timeout.timeout(config.timeout) do
      tcp_socket = tcp_server.accept
      tcp_socket.timeout = config.read_timeout if tcp_socket.respond_to? :timeout
      @connection = Connection.new(self, tcp_socket: tcp_socket)
      @connection.run
    ensure
      shutdown
    end
  end

  # Currently, the server will shutdown after a single connection has been
  # accepted and closed.  This may change in the future.  Call #shutdown
  # explicitly to ensure the server socket is unbound.
  def shutdown
    connection&.close
    commands&.close if connection&.commands&.closed?&.!
    tcp_server.close
  end

  # A Queue that contains every command the server has received.
  #
  # NOTE: This is not available until the connection has been accepted.
  def commands; connection.commands end

  # A Queue that contains every command the server has received.
  def state; connection.state end

  # See CommandRouter#on
  def on(...) connection&.on(...) end

  private

  attr_reader :tcp_server, :connection

end
