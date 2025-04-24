# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPAuthenticateTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  test("#authenticate sends an initial response " \
       "when supported by both the mechanism and the server") do
    with_fake_server(
      preauth: false, cleartext_auth: true, sasl_ir: true
    ) do |server, imap|
      imap.authenticate("PLAIN", "test_user", "test-password")
      cmd = server.commands.pop
      assert_equal "AUTHENTICATE", cmd.name
      assert_equal(["PLAIN", ["\x00test_user\x00test-password"].pack("m0")],
                   cmd.args)
      assert_empty server.commands
    end
  end

  test("#authenticate sends '=' as the initial reponse " \
       "when the initial response is an empty string") do
    with_fake_server(
      preauth: false, cleartext_auth: true,
      sasl_ir: true, sasl_mechanisms: %i[EXTERNAL],
    ) do |server, imap|
      server.on "AUTHENTICATE" do |cmd|
        server.state.authenticate(server.config.user)
        cmd.done_ok
      end
      imap.authenticate("EXTERNAL")
      cmd = server.commands.pop
      assert_equal "AUTHENTICATE", cmd.name
      assert_equal %w[EXTERNAL =], cmd.args
      assert_empty server.commands rescue pp server.commands.pop
    end
  end

  test("#authenticate never sends an initial response " \
       "when the server doesn't explicitly support the mechanism") do
    with_fake_server(
      preauth: false, cleartext_auth: true,
      sasl_ir: true, sasl_mechanisms: %i[SCRAM-SHA-1 SCRAM-SHA-256],
    ) do |server, imap|
      imap.authenticate("PLAIN", "test_user", "test-password")
      cmd, cont = 2.times.map { server.commands.pop }
      assert_equal %w[AUTHENTICATE PLAIN], [cmd.name, *cmd.args]
      assert_equal(["\x00test_user\x00test-password"].pack("m0"),
                   cont[:continuation].strip)
      assert_empty server.commands
    end
  end

  test("#authenticate never sends an initial response " \
       "when the server isn't capable") do
    with_fake_server(
      preauth: false, cleartext_auth: true, sasl_ir: false
    ) do |server, imap|
      imap.authenticate("PLAIN", "test_user", "test-password")
      cmd, cont = 2.times.map { server.commands.pop }
      assert_equal %w[AUTHENTICATE PLAIN], [cmd.name, *cmd.args]
      assert_equal(["\x00test_user\x00test-password"].pack("m0"),
                   cont[:continuation].strip)
      assert_empty server.commands
    end
  end

  test("#authenticate never sends an initial response " \
       "when sasl_ir: false") do
    [true, false].each do |server_support|
      with_fake_server(
        preauth: false, cleartext_auth: true, sasl_ir: server_support
      ) do |server, imap|
        imap.authenticate("PLAIN", "test_user", "test-password", sasl_ir: false)
        cmd, cont = 2.times.map { server.commands.pop }
        assert_equal %w[AUTHENTICATE PLAIN], [cmd.name, *cmd.args]
        assert_equal(["\x00test_user\x00test-password"].pack("m0"),
                     cont[:continuation].strip)
        assert_empty server.commands
      end
    end
  end

  test("#authenticate without cached capabilities never sends initial response " \
       "when config.sasl_ir: :when_capabilities_cached") do
    [true, false].each do |server_support|
      with_fake_server(
        preauth: false, cleartext_auth: true, sasl_ir: server_support,
        greeting_capabilities: false,
      ) do |server, imap|
        imap.config.sasl_ir = :when_capabilities_cached
        imap.authenticate("PLAIN", "test_user", "test-password")
        cmd, cont = 2.times.map { server.commands.pop }
        assert_equal %w[AUTHENTICATE PLAIN], [cmd.name, *cmd.args]
        assert_equal(["\x00test_user\x00test-password"].pack("m0"),
                     cont[:continuation].strip)
        assert_empty server.commands
      end
    end
  end

  test("#authenticate with cached capabilities sends an initial response " \
       "when config.sasl_ir: :when_capabilities_cached " \
       "and supported by both the mechanism and the server") do
    with_fake_server(
      preauth: false, cleartext_auth: true, sasl_ir: true,
      greeting_capabilities: true,
    ) do |server, imap|
      imap.config.sasl_ir = :when_capabilities_cached
      imap.authenticate("PLAIN", "test_user", "test-password")
      cmd = server.commands.pop
      assert_equal "AUTHENTICATE", cmd.name
      assert_equal(["PLAIN", ["\x00test_user\x00test-password"].pack("m0")],
                    cmd.args)
      assert_empty server.commands
    end
  end

  test("#authenticate with cached capabilities doesn't send initial response " \
       "when config.sasl_ir: :when_capabilities_cached " \
       "and not supported by the server") do
    with_fake_server(
      preauth: false, cleartext_auth: true, sasl_ir: false,
      greeting_capabilities: true,
    ) do |server, imap|
      imap.config.sasl_ir = :when_capabilities_cached
      imap.authenticate("PLAIN", "test_user", "test-password")
      cmd, cont = 2.times.map { server.commands.pop }
      assert_equal %w[AUTHENTICATE PLAIN], [cmd.name, *cmd.args]
      assert_equal(["\x00test_user\x00test-password"].pack("m0"),
                    cont[:continuation].strip)
      assert_empty server.commands
    end
  end

  test("#authenticate never sends an initial response " \
       "when config.sasl_ir: false") do
    [true, false].each do |server_support|
      with_fake_server(
        preauth: false, cleartext_auth: true, sasl_ir: server_support
      ) do |server, imap|
        imap.config.sasl_ir = false
        imap.authenticate("PLAIN", "test_user", "test-password")
        cmd, cont = 2.times.map { server.commands.pop }
        assert_equal %w[AUTHENTICATE PLAIN], [cmd.name, *cmd.args]
        assert_equal(["\x00test_user\x00test-password"].pack("m0"),
                     cont[:continuation].strip)
        assert_empty server.commands
      end
    end
  end

  test("#authenticate never sends an initial response " \
       "when the mechanism does not support client-first") do
    with_fake_server(
      preauth: false, cleartext_auth: true,
      sasl_ir: true, sasl_mechanisms: %i[DIGEST-MD5]
    ) do |server, imap|
      server.on "AUTHENTICATE" do |cmd|
        response_b64 = cmd.request_continuation(
          [
            %w[
              realm="somerealm"
              nonce="OA6MG9tEQGm2hh"
              qop="auth"
              charset=utf-8
              algorithm=md5-sess
            ].join(",")
          ].pack("m0")
        )
        state.commands << {continuation: response_b64}
        response_b64 = cmd.request_continuation(["rspauth="].pack("m0"))
        state.commands << {continuation: response_b64}
        server.state.authenticate(server.config.user)
        cmd.done_ok
      end
      imap.authenticate(:digest_md5, "test_user", "test-password",
                        warn_deprecation: false)
      cmd, cont1, cont2 = 3.times.map { server.commands.pop }
      assert_equal %w[AUTHENTICATE DIGEST-MD5], [cmd.name, *cmd.args]
      assert_match(%r{\A[a-z0-9+/]+=*\z}i, cont1[:continuation].strip)
      assert_empty cont2[:continuation].strip
      assert_empty server.commands
    end
  end

  test("#authenticate disconnects and raises SASL::AuthenticationFailed " \
       "when the server succeeds prematurely") do
    with_fake_server(
      preauth: false, cleartext_auth: true,
      sasl_ir: true, sasl_mechanisms: %i[DIGEST-MD5]
    ) do |server, imap|
      server.on "AUTHENTICATE" do |cmd|
        response_b64 = cmd.request_continuation(
          [
            %w[
              realm="somerealm"
              nonce="OA6MG9tEQGm2hh"
              qop="auth"
              charset=utf-8
              algorithm=md5-sess
            ].join(",")
          ].pack("m0")
        )
        state.commands << {continuation: response_b64}
        server.state.authenticate(server.config.user)
        cmd.done_ok
      end
      assert_raise(Net::IMAP::SASL::AuthenticationIncomplete) do
        imap.authenticate("DIGEST-MD5", "test_user", "test-password",
                          warn_deprecation: false)
      end
      assert imap.disconnected?
    end
  end

end
