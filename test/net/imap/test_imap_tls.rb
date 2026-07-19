# frozen_string_literal: true

require_relative "../../lib/helper"

# This file is for directly testing both implicit TLS connection and the
# STARTTLS command.
#
# Note that, although the default for test connections is plain-text, some other
# test files also use TLS connections when the TLS state affects the behavior
# of the methods being tested.
class IMAP_TLS_Test < Net::IMAP::TestCase
  CA_FILE = File.expand_path("../fixtures/cacert.pem", __dir__)
  SERVER_KEY = File.expand_path("../fixtures/server.key", __dir__)
  SERVER_CERT = File.expand_path("../fixtures/server.crt", __dir__)

  include Net::IMAP::TestCase::SimpleTCPServerHelper

  if defined?(OpenSSL)
    def test_imaps_unknown_ca
      assert_local_raise(OpenSSL::SSL::SSLError) do
        imaps_test do |port|
          begin
            Net::IMAP.new("localhost",
                          :port => port,
                          :ssl => true)
          rescue SystemCallError
            skip $!
          end
        end
      end
    end

    def test_imaps_with_ca_file
      # Assert verified *after* the imaps_test and assert_nothing_raised blocks.
      # Otherwise, failures can't logout and need to wait for the timeout.
      verified, imap = :unknown, nil
      assert_nothing_raised do
        begin
          imaps_test do |port|
            imap = Net::IMAP.new("localhost",
                                port: port,
                                ssl: { :ca_file => CA_FILE })
            verified = imap.tls_verified?
            imap
          rescue SystemCallError
            skip $!
          end
        rescue OpenSSL::SSL::SSLError => e
          raise e unless /darwin/ =~ RUBY_PLATFORM
        end
      end
      assert_equal true, verified
      assert_equal true, imap.tls_verified?
      assert_equal({ca_file: CA_FILE}, imap.ssl_ctx_params)
      assert_equal(CA_FILE, imap.ssl_ctx.ca_file)
      assert_equal(OpenSSL::SSL::VERIFY_PEER, imap.ssl_ctx.verify_mode)
      assert imap.ssl_ctx.verify_hostname
    end

    def test_imaps_verify_none
      # Assert verified *after* the imaps_test and assert_nothing_raised blocks.
      # Otherwise, failures can't logout and need to wait for the timeout.
      verified, imap = :unknown, nil
      assert_nothing_raised do
        begin
          imaps_test do |port|
            imap = Net::IMAP.new(
              server_addr,
              port: port,
              ssl: { :verify_mode => OpenSSL::SSL::VERIFY_NONE }
            )
            verified = imap.tls_verified?
            imap
          end
        rescue OpenSSL::SSL::SSLError => e
          raise e unless /darwin/ =~ RUBY_PLATFORM
        end
      end
      assert_equal false, verified
      assert_equal false, imap.tls_verified?
      assert_equal({verify_mode: OpenSSL::SSL::VERIFY_NONE},
                   imap.ssl_ctx_params)
      assert_equal(nil, imap.ssl_ctx.ca_file)
      assert_equal(OpenSSL::SSL::VERIFY_NONE, imap.ssl_ctx.verify_mode)
    end

    def test_imaps_post_connection_check
      assert_local_raise(OpenSSL::SSL::SSLError) do
        imaps_test do |port|
          # server_addr is different from the hostname in the certificate,
          # so the following code should raise a SSLError.
          Net::IMAP.new(server_addr,
                        :port => port,
                        :ssl => { :ca_file => CA_FILE })
        end
      end
    end

    def test_starttls_unknown_ca
      omit "This test is not working with Windows" if RUBY_PLATFORM =~ /mswin|mingw/

      imap = nil
      ex = nil
      starttls_test do |port|
        imap = Net::IMAP.new("localhost", port: port)
        begin
          imap.starttls
        rescue => ex
        end
        imap
      end
      assert_kind_of(OpenSSL::SSL::SSLError, ex)
      assert_local_backtrace ex
      assert_equal false, imap.tls_verified?
      assert_equal({}, imap.ssl_ctx_params)
      assert_equal(nil, imap.ssl_ctx.ca_file)
      assert_equal(OpenSSL::SSL::VERIFY_PEER, imap.ssl_ctx.verify_mode)
    end

    def test_starttls
      initial_verified, initial_ctx, initial_params = :unknown, :unknown, :unknown
      imap = nil
      starttls_test do |port|
        imap = Net::IMAP.new("localhost", :port => port)
        initial_verified = imap.tls_verified?
        initial_params   = imap.ssl_ctx_params
        initial_ctx      = imap.ssl_ctx
        imap.starttls(:ca_file => CA_FILE)
        imap
      end
      assert_equal false, initial_verified
      assert_equal false, initial_params
      assert_equal nil,   initial_ctx
      assert_equal true,  imap.tls_verified?
      assert_include imap.inspect, " TLS disconnected"
      assert_equal({ca_file: CA_FILE}, imap.ssl_ctx_params)
    rescue SystemCallError
      skip $!
    ensure
      if imap && !imap.disconnected?
        imap.disconnect
      end
    end

    def test_starttls_stripping_not_ok
      imap = nil
      server = create_tcp_server
      port = server.addr[1]
      start_server do
        sock = server.accept
        begin
          sock.print("* OK test server\r\n")
          sock.gets
          sock.print("RUBY0001 BUG unhandled command\r\n")
        ensure
          sock.close
          server.close
        end
      end
      begin
        imap = Net::IMAP.new("localhost", :port => port)
        assert_reraised(Net::IMAP::InvalidResponseError, imap:) do
          imap.starttls(:ca_file => CA_FILE)
        end
        assert imap.disconnected?
      ensure
        imap.disconnect if imap && !imap.disconnected?
      end

      assert_equal false, imap.tls_verified?
      assert_include imap.inspect, " PLAINTEXT (TLS NOT STARTED) "
      assert_equal({ca_file: CA_FILE},        imap.ssl_ctx_params)
      assert_equal(CA_FILE,                   imap.ssl_ctx.ca_file)
      assert_equal(OpenSSL::SSL::VERIFY_PEER, imap.ssl_ctx.verify_mode)
    end

    def test_starttls_stripping_ok_sent_before_response
      # to coordinate between threads (better than sleep)
      server_to_client, client_to_server = Queue.new, Queue.new
      rcvr_to_client = Queue.new
      imap = nil
      server = create_tcp_server
      port = server.addr[1]
      start_server do
        sock = server.accept
        begin
          sock.print("* OK test server\r\n")
          assert_equal :send_malicious_response, client_to_server.pop
          sock.print("RUBY0001 OK hahaha, fooled you!\r\n")
          server_to_client << :malicious_response_sent
          sock.gets
        ensure
          sock.close
          server.close
        end
      end
      timeout = 5
      timeout *= EnvUtil.timeout_scale || 1 if defined?(EnvUtil.timeout_scale)
      begin
        Timeout.timeout(timeout) do
          imap = Net::IMAP.new("localhost", :port => port)
          imap.add_response_handler do |resp| rcvr_to_client << resp end
          client_to_server << :send_malicious_response
          assert_equal :malicious_response_sent, server_to_client.pop
          # Wait until the receive thread has parsed the injected response and
          # stored it in @tagged_responses, so finish_sending_command can see it.
          # (handle_response stores the tagged response before calling handlers.)
          rcvr_to_client.pop
          assert_local_raise(Net::IMAP::InvalidTaggedResponseError) do
            imap.starttls(:ca_file => CA_FILE)
          end
          assert imap.disconnected?
        end
      ensure
        imap.disconnect if imap && !imap.disconnected?
      end
      assert_equal false, imap.tls_verified?
      assert_include imap.inspect, " PLAINTEXT (TLS NOT STARTED) "
      assert_equal({ca_file: CA_FILE},        imap.ssl_ctx_params)
      assert_equal(CA_FILE,                   imap.ssl_ctx.ca_file)
      assert_equal(OpenSSL::SSL::VERIFY_PEER, imap.ssl_ctx.verify_mode)
    end

  end

  private

  def imaps_test(timeout: 10)
    Timeout.timeout(timeout) do
      server = create_tcp_server
      port = server.addr[1]
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.ca_file = CA_FILE
      ctx.key = File.open(SERVER_KEY) { |f|
        OpenSSL::PKey::RSA.new(f)
      }
      ctx.cert = File.open(SERVER_CERT) { |f|
        OpenSSL::X509::Certificate.new(f)
      }
      ssl_server = OpenSSL::SSL::SSLServer.new(server, ctx)
      started = false
      ths = Thread.start do
        Thread.current.report_on_exception = false # always join-ed
        begin
          started = true
          sock = ssl_server.accept
          begin
            sock.print("* OK test server\r\n")
            sock.gets
            sock.print("* BYE terminating connection\r\n")
            sock.print("RUBY0001 OK LOGOUT completed\r\n")
          ensure
            sock.close
          end
        rescue Errno::EPIPE, Errno::ECONNRESET, Errno::ECONNABORTED
        rescue OpenSSL::SSL::SSLError
        end
      end
      sleep 0.001 until started
      begin
        begin
          imap = yield(port)
          imap.logout
          imap
        ensure
          imap.disconnect if imap
        end
      ensure
        ssl_server.close
        ths.join
      end
    end
  end

  def starttls_test
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        sock.gets
        sock.print("RUBY0001 OK completed\r\n")
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.ca_file = CA_FILE
        ctx.key = File.open(SERVER_KEY) { |f|
          OpenSSL::PKey::RSA.new(f)
        }
        ctx.cert = File.open(SERVER_CERT) { |f|
          OpenSSL::X509::Certificate.new(f)
        }
        sock = OpenSSL::SSL::SSLSocket.new(sock, ctx)
        sock.sync_close = true
        sock.accept
        sock.gets
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0002 OK LOGOUT completed\r\n")
      rescue OpenSSL::SSL::SSLError
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = yield(port)
      imap.logout if !imap.disconnected?
    ensure
      imap.disconnect if imap && !imap.disconnected?
    end
  end

end
