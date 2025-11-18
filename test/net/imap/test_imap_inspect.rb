# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPInspectTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  def format_inspect(client, details, *args)
    "#<Net::IMAP:0x%s %s:%s %s>" % [
      "%08x" % client.__id__, # NOTE: this is different from `super`
      client.host,
      client.port,
      format(details, *args),
    ]
  end

  test "#inspect for every connection state (plaintext)" do
    with_fake_server(preauth: false) do |server, imap|
      assert_equal(format_inspect(imap, "PLAINTEXT not_authenticated"),
                   imap.inspect)
      # AUTHENTICATE, SELECT, CLOSE
      imap.authenticate :plain, "test_user", "test-password"
      assert_equal(format_inspect(imap, "PLAINTEXT authenticated"),
                   imap.inspect)
      imap.select "INBOX"
      assert_equal(format_inspect(imap, "PLAINTEXT selected"),
                   imap.inspect)
      imap.close
      assert_equal(format_inspect(imap, "PLAINTEXT authenticated"),
                   imap.inspect)
      imap.logout
      assert_equal(format_inspect(imap, "PLAINTEXT logout"),
                   imap.inspect)
      imap.disconnect
      assert_equal(format_inspect(imap, "PLAINTEXT disconnected"),
                   imap.inspect)
    end
  end

  test "#inspect for TLS verified" do
    with_fake_server(implicit_tls: true) do |server, imap|
      assert_equal(format_inspect(imap, "TLS authenticated"),
                   imap.inspect)
      imap.logout
      assert_equal(format_inspect(imap, "TLS logout"),
                   imap.inspect)
      imap.disconnect
      assert_equal(format_inspect(imap, "TLS disconnected"),
                   imap.inspect)
    end
  end

  test "#inspect for TLS unverified" do
    with_fake_server(preauth: false) do |server, imap|
      imap.starttls verify_mode: OpenSSL::SSL::VERIFY_NONE
      assert_equal(format_inspect(imap, "TLS (NOT VERIFIED) not_authenticated"),
                   imap.inspect)
      imap.logout
      assert_equal(format_inspect(imap, "TLS (NOT VERIFIED) logout"),
                   imap.inspect)
      imap.disconnect
      assert_equal(format_inspect(imap, "TLS (NOT VERIFIED) disconnected"),
                   imap.inspect)
    end
  end

  def config_id(config)
    Kernel.instance_method(:to_s).bind_call(config).match(/0x(\h*)>/)[1]
  end

  test "#inspect with config overrides" do
    run_fake_server_in_thread do |server|
      with_client("localhost", port: server.port, config: 0.5) do |client|
        assert_equal(
          format_inspect(
            client, "PLAINTEXT authenticated config=#<%s:0x%s inherits from %s>",
            Net::IMAP::Config, config_id(client.config), "Net::IMAP::Config[0.5]"
          ),
          client.inspect
        )
        client.config.sasl_ir = true
        assert_equal(
          format_inspect(client, "PLAINTEXT authenticated config=%p",
                         client.config),
          client.inspect
        )
      end
    end
  end

end
