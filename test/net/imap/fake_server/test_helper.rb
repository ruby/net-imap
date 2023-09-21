# frozen_string_literal: true

require_relative "../fake_server"

module Net::IMAP::FakeServer::TestHelper

  def run_fake_server_in_thread(ignore_io_error: false, timeout: 5, **opts)
    Timeout.timeout(timeout) do
      server = Net::IMAP::FakeServer.new(timeout: timeout, **opts)
      @threads << Thread.new do
        server.run
      rescue IOError
        raise unless ignore_io_error
      end
      yield server
    ensure
      server&.shutdown
    end
  end

  def with_client(*args, **kwargs)
    client = Net::IMAP.new(*args, **kwargs)
    yield client
  ensure
    if client && !client.disconnected?
      client.logout rescue pp $!
      client.disconnect unless client.disconnected?
    end
  end

  def with_fake_server(select: nil, **opts)
    run_fake_server_in_thread(**opts) do |server|
      tls = opts[:implicit_tls]
      tls = {ca_file: server.config.tls[:ca_file]} if tls == true
      with_client("localhost", port: server.port, ssl: tls) do |client|
        if select
          client.select(select)
          server.commands.pop
          assert server.state.selected?
        end
        yield server, client
      end
    end
  end

end
