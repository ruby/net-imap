# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPDeprecatedClientOptionsTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  def setup
    Net::IMAP.config.reset
    @do_not_reverse_lookup = Socket.do_not_reverse_lookup
    Socket.do_not_reverse_lookup = true
    @threads = []
  end

  def teardown
    assert_join_threads(@threads) unless @threads.empty?
  ensure
    Socket.do_not_reverse_lookup = @do_not_reverse_lookup
  end

  class InitializeTests < IMAPDeprecatedClientOptionsTest

    test "Convert obsolete options hash to keywords" do
      run_fake_server_in_thread do |server|
        with_client(server.host, {port: server.port, ssl: false}, **{}) do |client|
          assert_equal server.host, client.host
          assert_equal server.port, client.port
          assert_equal false, client.ssl_ctx_params
        end
      end
    end

    test "Convert obsolete port argument to :port keyword" do
      run_fake_server_in_thread do |server|
        with_client(server.host, server.port) do |client|
          assert_equal server.host, client.host
          assert_equal server.port, client.port
          assert_equal false, client.ssl_ctx_params
        end
      end
    end

    test "Convert deprecated usessl (= false) with warning" do
      run_fake_server_in_thread do |server|
        assert_deprecated_warning(/Call Net::IMAP\.new with keyword/i) do
          with_client(server.host, server.port, false, :who, :cares) do |client|
            assert_equal server.host, client.host
            assert_equal server.port, client.port
            assert_equal false, client.ssl_ctx_params
          end
        end
      end
    end

    test "Convert deprecated usessl (= true) and certs, with warning" do
      run_fake_server_in_thread(implicit_tls: true) do |server|
        certs = server.config.tls[:ca_file]
        assert_deprecated_warning(/Call Net::IMAP\.new with keyword/i) do
          with_client("localhost", server.port, true, certs) do |client|
            assert_equal "localhost", client.host
            assert_equal server.port, client.port
            assert_equal(
              {ca_file: certs, verify_mode: OpenSSL::SSL::VERIFY_PEER},
              client.ssl_ctx_params
            )
          end
        end
      end
    end

    test "Convert deprecated usessl (= true) and verify (= false), with warning" do
      run_fake_server_in_thread(implicit_tls: true) do |server|
        assert_deprecated_warning(/Call Net::IMAP\.new with keyword/i) do
          with_client("localhost", server.port, true, nil, false) do |client|
            assert_equal "localhost", client.host
            assert_equal server.port, client.port
            assert_equal(
              {verify_mode: OpenSSL::SSL::VERIFY_NONE},
              client.ssl_ctx_params
            )
            assert_equal OpenSSL::SSL::VERIFY_NONE, client.ssl_ctx.verify_mode
          end
        end
      end
    end

    test "combined options hash and keyword args raises ArgumentError" do
      assert_raise_with_message ArgumentError, /deprecated.*keyword arg/ do
        Net::IMAP.new("localhost", {port: 993}, ssl: true)
      end
    end

    test "combined options hash and ssl args raises ArgumentError" do
      assert_raise_with_message ArgumentError, /deprecated SSL.*options hash/ do
        Net::IMAP.new("localhost", {port: 993}, true)
      end
    end

  end

  class StartTLSTests < IMAPDeprecatedClientOptionsTest
    test "Convert obsolete options hash to keywords" do
      with_fake_server(preauth: false) do |server, imap|
        imap.starttls(ca_file: server.config.tls[:ca_file], min_version: :TLS1_2)
        assert_equal(
          {ca_file: server.config.tls[:ca_file], min_version: :TLS1_2},
          imap.ssl_ctx_params
        )
        assert imap.ssl_ctx.verify_hostname
        assert_equal(server.config.tls[:ca_file], imap.ssl_ctx.ca_file)
      end
    end

    test "Convert deprecated certs, verify with warning" do
      with_fake_server(preauth: false) do |server, imap|
        assert_deprecated_warning(/Call Net::IMAP#starttls with keyword/i) do
          imap.starttls(server.config.tls[:ca_file], false)
        end
        assert_equal(
          {
            ca_file: server.config.tls[:ca_file],
            verify_mode: OpenSSL::SSL::VERIFY_NONE,
          },
          imap.ssl_ctx_params
        )
        assert_equal server.config.tls[:ca_file], imap.ssl_ctx.ca_file
      end
    end

    test "combined options hash and keyword args raises ArgumentError" do
      with_fake_server(preauth: false) do |server, imap|
        assert_raise(ArgumentError) do
          imap.starttls({min_version: :TLS1_2},
                        ca_file: server.config.tls[:ca_file])
        end
      end
    end

    test "combined options hash and ssl args raises ArgumentError" do
      with_fake_server(preauth: false) do |server, imap|
        assert_raise(ArgumentError) do
          imap.starttls({min_version: :TLS1_2}, false)
        end
      end
    end
  end

end
