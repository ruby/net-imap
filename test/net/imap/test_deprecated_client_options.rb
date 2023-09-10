# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class DeprecatedClientOptionsTest < Test::Unit::TestCase
  include Net::IMAP::FakeServer::TestHelper

  def setup
    @do_not_reverse_lookup = Socket.do_not_reverse_lookup
    Socket.do_not_reverse_lookup = true
    @threads = []
  end

  def teardown
    assert_join_threads(@threads) unless @threads.empty?
  ensure
    Socket.do_not_reverse_lookup = @do_not_reverse_lookup
  end

  class InitializeTests < DeprecatedClientOptionsTest

    test "Convert obsolete options hash to keywords" do
      run_fake_server_in_thread do |server|
        with_client(server.host, {port: server.port, ssl: false}) do |client|
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
      ex = nil
      run_fake_server_in_thread(
        ignore_io_error: true, implicit_tls: true
      ) do |server|
        imap = Net::IMAP.new("localhost", {port: 993}, ssl: true)
      rescue => ex
        nil
      ensure
        imap&.disconnect
      end
      assert_equal ArgumentError, ex.class
    end

    test "combined options hash and ssl args raises ArgumentError" do
      ex = nil
      run_fake_server_in_thread(
        ignore_io_error: true, implicit_tls: true
      ) do |server|
        imap = Net::IMAP.new("localhost", {port: 993}, true)
      rescue => ex
        nil
      ensure
        imap&.disconnect
      end
      assert_equal ArgumentError, ex.class
    end

  end

end
