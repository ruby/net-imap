# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPCapabilitiesTest < Net::IMAP::TestCase

  include Net::IMAP::FakeServer::TestHelper

  def setup
    Net::IMAP.config.reset
    @do_not_reverse_lookup = Socket.do_not_reverse_lookup
    Socket.do_not_reverse_lookup = true
    @threads = []
  end

  def teardown
    if !@threads.empty?
      assert_join_threads(@threads)
    end
  ensure
    Socket.do_not_reverse_lookup = @do_not_reverse_lookup
  end

  test "#capabilities returns cached CAPABILITY data" do
    with_fake_server do |server, imap|
      imap.clear_cached_capabilities
      assert_empty server.commands
      10.times do
        assert_equal(%w[IMAP4REV1 NAMESPACE MOVE IDLE UTF8=ACCEPT],
                     imap.capabilities)
      end
      # only one CAPABILITY command was sent
      assert_equal "CAPABILITY", server.commands.pop.name
      assert_empty server.commands
    end
  end

  test "#capable?(name) checks cached CAPABILITY data for name" do
    with_fake_server do |server, imap|
      imap.clear_cached_capabilities
      assert_empty server.commands
      10.times do
        assert imap.capable? "IMAP4rev1"
        assert imap.capable? :NAMESPACE
        assert imap.capable? "idle"
        refute imap.capable? "LOGINDISABLED"
        refute imap.capable? "auth=plain"
      end
      # only one CAPABILITY command was sent
      assert_equal "CAPABILITY", server.commands.pop.name
      assert_empty server.commands
    end
  end

  test "#auth_capable?(name) checks cached capabilities for AUTH=name" do
    with_fake_server(
      preauth: false, cleartext_auth: true,
      sasl_mechanisms: %i[PLAIN SCRAM-SHA-1 SCRAM-SHA-256 XOAUTH2 OAUTHBEARER],
    ) do |server, imap|
      imap.clear_cached_capabilities
      assert_empty server.commands
      10.times do
        assert imap.auth_capable? :PLAIN
        assert imap.auth_capable? "scram-sha-1"
        assert imap.auth_capable? "OAuthBearer"
        assert imap.auth_capable? :XOAuth2
        refute imap.auth_capable? "EXTERNAL"
        refute imap.auth_capable? :LOGIN
        refute imap.auth_capable? "anonymous"
      end
      # only one CAPABILITY command was sent
      assert_equal "CAPABILITY", server.commands.pop.name
      assert_empty server.commands
    end
  end

  test "#auth_mechanisms reports cached capabilities with AUTH={name}" do
    with_fake_server(
      preauth: false, cleartext_auth: true,
      sasl_mechanisms: %i[PLAIN SCRAM-SHA-1 SCRAM-SHA-256 XOAUTH2 OAUTHBEARER],
    ) do |server, imap|
      imap.clear_cached_capabilities
      assert_empty server.commands
      10.times do
        assert_equal(%w[PLAIN SCRAM-SHA-1 SCRAM-SHA-256 XOAUTH2 OAUTHBEARER],
                     imap.auth_mechanisms)
      end
      # only one CAPABILITY command was sent
      assert_equal "CAPABILITY", server.commands.pop.name
      assert_empty server.commands
    end
  end

  test "#clear_cached_capabilities clears cached capabilities" do
    with_fake_server do |server, imap|
      assert imap.capable?(:IMAP4rev1)
      assert imap.capabilities_cached?
      assert_empty server.commands
      imap.clear_cached_capabilities
      refute imap.capabilities_cached?
      assert imap.capable?(:IMAP4rev1)
      assert_equal "CAPABILITY", server.commands.pop.name
      assert imap.capabilities_cached?
    end
  end

  test "#capability caches its result" do
    with_fake_server(greeting_capabilities: false) do |server, imap|
      imap.capability
      assert imap.capabilities_cached?
      assert_equal "CAPABILITY", server.commands.pop.name
      assert_empty server.commands
    end
  end

  test "#capabilities caches greeting capabilities (cleartext)" do
    with_fake_server(
      preauth: false, cleartext_login: false, cleartext_auth: false,
    ) do |server, imap|
      assert imap.capabilities_cached?
      assert_equal %w[IMAP4REV1 STARTTLS LOGINDISABLED], imap.capabilities
      assert_empty imap.auth_mechanisms
      refute imap.auth_capable? "plain"
      refute imap.capable? "plain"
      assert_empty server.commands
    end
  end

  test "#capabilities caches greeting capabilities (PREAUTH)" do
    with_fake_server(preauth: true) do |server, imap|
      assert imap.capabilities_cached?
      assert_equal %w[IMAP4REV1 NAMESPACE MOVE IDLE UTF8=ACCEPT],
                   imap.capabilities
      assert_empty server.commands
    end
  end

  if defined?(OpenSSL::SSL::SSLError)
    test "#capabilities caches greeting capabilities (implicit TLS)" do
      with_fake_server(preauth: false, implicit_tls: true) do |server, imap|
        assert imap.capabilities_cached?
        assert_equal %w[IMAP4REV1 AUTH=PLAIN], imap.capabilities
        assert_equal %w[PLAIN], imap.auth_mechanisms
        assert imap.capable? :IMAP4rev1
        assert imap.auth_capable? "plain"
        assert_empty server.commands
      end
    end

    test "#capabilities cache is cleared after #starttls" do
      with_fake_server(preauth: false, cleartext_auth: false) do |server, imap|
        assert imap.capabilities_cached?
        assert imap.capable? :IMAP4rev1
        refute imap.auth_capable? "plain"

        imap.starttls(ca_file: server.config.tls[:ca_file])
        assert_equal "STARTTLS", server.commands.pop.name
        refute imap.capabilities_cached?

        assert imap.capable? :IMAP4rev1
        assert imap.auth_capable? "plain"
        assert_equal "CAPABILITY", server.commands.pop.name
        assert imap.capabilities_cached?
        assert_empty server.commands
      end
    end
  end

  test "#capabilities cache is cleared after #login" do
    with_fake_server(preauth: false, cleartext_login: true) do |server, imap|
      assert imap.capable? :IMAP4rev1
      assert imap.capabilities_cached?

      imap.login("test_user", "test-password")
      assert_equal "LOGIN", server.commands.pop.name
      refute imap.capabilities_cached?

      assert imap.capable? :IMAP4rev1
      assert_equal "CAPABILITY", server.commands.pop.name
      assert imap.capabilities_cached?
      assert_empty server.commands
    end
  end

  test "#capabilities cache is cleared after #authenticate" do
    with_fake_server(preauth: false, cleartext_auth: true) do |server, imap|
      assert imap.capable?("AUTH=PLAIN")
      assert imap.auth_capable?("PLAIN")

      imap.authenticate("PLAIN", "test_user", "test-password")
      assert_equal "AUTHENTICATE", server.commands.pop.name
      assert server.commands.pop[:continuation]
      refute imap.capabilities_cached?

      assert imap.capable? :IMAP4rev1
      refute imap.auth_capable?("PLAIN")
      assert_empty imap.auth_mechanisms
      assert_equal "CAPABILITY", server.commands.pop.name
      assert_empty server.commands
    end
  end

  # TODO: should we warn about this?
  test "#capabilities cache IGNORES tagged OK response to STARTTLS" do
    with_fake_server(preauth: false) do |server, imap|
      server.on "STARTTLS" do |cmd|
        cmd.done_ok code: "[CAPABILITY IMAP4rev1 AUTH=PLAIN fnord]"
        server.state.use_tls
      end

      imap.starttls(ca_file: server.config.tls[:ca_file])
      assert_equal "STARTTLS", server.commands.pop.name
      refute imap.capabilities_cached?

      refute imap.capable? "fnord"
      assert_equal "CAPABILITY", server.commands.pop.name
    end
  end

  test "#capabilities caches tagged OK response to LOGIN" do
    with_fake_server(preauth: false, cleartext_login: true) do |server, imap|
      server.on "LOGIN" do |cmd|
        server.state.authenticate server.config.user
        cmd.done_ok code: "[CAPABILITY IMAP4rev1 IMAP4rev2 MOVE NAMESPACE" \
                           " ENABLE IDLE UIDPLUS UNSELECT UTF8=ACCEPT]"
      end

      imap.login("test_user", "test-password")
      assert_equal "LOGIN", server.commands.pop.name
      assert imap.capabilities_cached?

      assert imap.capable? :IMAP4rev1
      assert imap.capable? :IMAP4rev2
      assert imap.capable? "UIDPLUS"
      assert_empty server.commands
    end
  end

  test "#capabilities caches tagged OK response to AUTHENTICATE" do
    with_fake_server(preauth: false, cleartext_login: true) do |server, imap|
      server.on "AUTHENTICATE" do |cmd|
        cmd.request_continuation ""
        server.state.authenticate server.config.user
        cmd.done_ok code: "[CAPABILITY IMAP4rev1 IMAP4rev2 MOVE NAMESPACE" \
                           " ENABLE IDLE UIDPLUS UNSELECT UTF8=ACCEPT]"
      end

      imap.authenticate("PLAIN", "test_user", "test-password")
      assert_equal "AUTHENTICATE", server.commands.pop.name
      assert imap.capabilities_cached?

      assert imap.capable? :IMAP4rev1
      assert imap.capable? :IMAP4rev2
      assert imap.capable? "UIDPLUS"
      assert_empty server.commands
    end
  end

  test "#capabilities cache is NOT cleared after #login fails" do
    with_fake_server(preauth: false, cleartext_login: true) do |server, imap|
      original_capabilities = imap.capabilities
      begin
        imap.login("wrong_user", "wrong-password")
      rescue Net::IMAP::NoResponseError
      end
      assert_equal "LOGIN", server.commands.pop.name
      assert_equal original_capabilities, imap.capabilities
      assert_empty server.commands
    end
  end

  test "#capabilities cache is NOT cleared after #authenticate fails" do
    with_fake_server(preauth: false, cleartext_auth: true) do |server, imap|
      original_capabilities = imap.capabilities
      begin
        imap.authenticate("PLAIN", "wrong_user", "wrong-password")
      rescue Net::IMAP::NoResponseError
      end
      assert_equal "AUTHENTICATE", server.commands.pop.name
      assert server.commands.pop[:continuation]
      assert_equal original_capabilities, imap.capabilities
      assert_empty server.commands
    end
  end

  # NOTE: other recorded responses are cleared after #select
  test "#capabilities cache is retained after selecting a mailbox" do
    with_fake_server do |server, imap|
      original_capabilities = imap.capabilities
      imap.select "inbox"
      assert_equal "SELECT", server.commands.pop.name
      assert_equal original_capabilities, imap.capabilities
      assert_empty server.commands
    end
  end

end
