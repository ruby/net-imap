# frozen_string_literal: true

require_relative "../fake_server"

module Net::IMAP::FakeServer::TestHelper

  def with_fake_server(select: nil, timeout: 5, **opts)
    Timeout.timeout(timeout) do
      server = Net::IMAP::FakeServer.new(timeout: timeout, **opts)
      @threads << Thread.new do server.run end if @threads
      tls = opts[:implicit_tls]
      tls = {ca_file: server.config.tls[:ca_file]} if tls == true
      client = Net::IMAP.new("localhost", port: server.port, ssl: tls)
      begin
        if select
          client.select(select)
          server.commands.pop
        end
        yield server, client
      ensure
        client.logout rescue pp $!
        client.disconnect if !client.disconnected?
      end
    ensure
      server&.shutdown
    end
  end

end
