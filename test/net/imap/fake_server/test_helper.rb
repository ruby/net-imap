# frozen_string_literal: true

require_relative "../fake_server"

module Net::IMAP::FakeServer::TestHelper

  def run_fake_server_in_thread(ignore_io_error: false,
                                report_on_exception: true,
                                timeout: 10, **opts)
    Timeout.timeout(timeout) do
      server = Net::IMAP::FakeServer.new(timeout: timeout, **opts)
      @threads << Thread.new do
        Thread.current.abort_on_exception  = false
        Thread.current.report_on_exception = report_on_exception
        server.run
      rescue IOError
        raise unless ignore_io_error
      end
      yield server
    ensure
      begin
        server&.shutdown
      rescue IOError
        raise unless ignore_io_error
      end
    end
  end

  def with_client(*args, **kwargs)
    client = Net::IMAP.new(*args, **kwargs)
    yield client
  ensure
    if client && !client.disconnected?
      client.logout!
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
