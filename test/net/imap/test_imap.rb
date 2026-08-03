# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPTest < Net::IMAP::TestCase
  # TODO: convert to use Net::IMAP::FakeServer::TestHelper
  include Net::IMAP::TestCase::SimpleTCPServerHelper
  include Net::IMAP::FakeServer::TestHelper

  # Similar to STARTTLS stripping test, but checks other commands too
  data(
    "IDLE"   => ->imap do imap.idle(1) do end end,
    "NOOP"   => ->imap do imap.noop end,
    "SELECT" => ->imap do imap.select("inbox") end,
  )
  test "premature tagged OK response" do |cmd|
    timeout = 5
    timeout *= EnvUtil.timeout_scale || 1 if defined?(EnvUtil.timeout_scale)
    Timeout.timeout(timeout) do
      server_to_client = Queue.new
      client_to_server = Queue.new
      rcvr_to_client   = Queue.new
      server = create_tcp_server
      port = server.addr[1]
      start_server do
        sock = server.accept
        begin
          sock.print("* OK test server\r\n")
          assert_equal :send_malicious_responses, client_to_server.pop
          sock.print("RUBY0001 OK invalid\r\n")
          sock.print("RUBY0002 OK false\r\n")
          sock.print("RUBY0003 OK tricky\r\n")
          server_to_client << :sent_malicious_responses
          sock.gets
        ensure
          sock.close
          server.close
        end
      end
      begin
        imap = Net::IMAP.new(server_addr, port:)
        i = 0
        imap.add_response_handler do |resp|
          rcvr_to_client << (i += 1)
        end
        client_to_server << :send_malicious_responses
        assert_equal :sent_malicious_responses, server_to_client.pop
        assert_equal [1, 2, 3], 3.times.map { rcvr_to_client.pop }
        # should respond this way for _any_ command
        omit_if_jruby "JRuby sometimes raises IOError instead"
        assert_local_raise(Net::IMAP::InvalidTaggedResponseError) do
          cmd.(imap)
        end
        assert imap.disconnected?
        assert_stream_closed_error do cmd.(imap) end
        assert_stream_closed_error do cmd.(imap) end
        assert_stream_closed_error do cmd.(imap) end
      ensure
        imap.disconnect if imap
      end
    end
  end

  def test_unexpected_eof
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        sock.gets
#       sock.print("* BYE terminating connection\r\n")
#       sock.print("RUBY0001 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      assert_local_raise EOFError do
        imap.logout
      end
    ensure
      imap.disconnect if imap
    end
  end

  BrokenResponseReaderTestError = Class.new(StandardError)

  test "exception from response reader" do
    with_fake_server ignore_io_error: true, ignore_abrupt_eof: true do |server, imap|
      handler = imap.add_response_handler do
        imap.instance_exec do
          def @reader.read_response_buffer
            raise BrokenResponseReaderTestError, "testing"
          end
        end
        imap.remove_response_handler handler
      end
      server.unsolicited "OK [ALERT] trigger read_response_buffer switcheroo"
      server.unsolicited "OK [ALERT] trigger reader error"
      # NOTE: closing the socket happens in the receiver thread, creating a race
      # condition if a client thread issues a command right *here*.
      #
      # If a command is called here, it may run before or after the response
      # reader error closes the connection.  If it runs before, then
      # `get_tagged_response` should return the BrokenResponseReaderTestError
      # exception.  If it runs after, we'll see the "stream closed" IOError.
      #
      # The distinction between these errors is not considered important enough
      # to justify delaying for the "correct" error or complex tests to capture
      # each possible case.
      #
      # By waiting for the receiver thread to close, this test ensures a stable
      # result: the socket will be closed and `@exception` will be assigned...
      # But, since `send_command` doesn't currently check this before attempting
      # to send, it simply raises the "stream closed" IOError.
      wait_for_receiver_thread_terminating(imap)

      assert imap.disconnected?
      assert_stream_closed_error do
        imap.noop
      end
      assert imap.disconnected?
    end
  end

  test "exception from response parser" do
    with_fake_server ignore_io_error: true, ignore_abrupt_eof: true do |server, imap|
      server.on "NOOP" do |resp|
        resp.puts "#{resp.tag} NOPE [SERVERBUG] this ain't right!"
      end
      assert_reraised(Net::IMAP::InvalidResponseError, /bad.*NOPE/, imap:) do
        imap.noop
      end
      assert imap.disconnected?
    end
    with_fake_server ignore_abrupt_eof: true do |server, imap|
      server.on "FETCH" do |resp|
        resp.untagged '1 FETCH (BODY[] ")'
        resp.done_ok
      end
      assert_reraised(Net::IMAP::ResponseParseError, imap:) do
        imap.fetch 1, "FAST"
      end
      assert imap.disconnected?
    end
  end

  def test_unexpected_bye
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK Gimap ready for requests from 75.101.246.151 33if2752585qyk.26\r\n")
        sock.gets
        sock.print("* BYE System Error 33if2752585qyk.26\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      assert_local_raise(Net::IMAP::ByeResponseError) do
        imap.login("user", "password")
      end
    end
  end

  def test_exception_during_shutdown
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        sock.gets
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0001 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      imap.instance_eval do
        def @sock.shutdown(*args)
          super
        ensure
          raise "error"
        end
      end
      imap.logout
    ensure
      assert_local_raise(RuntimeError) do
        imap.disconnect
      end
    end
  end

  def test_connection_closed_without_greeting
    unless (ObjectSpace.each_object(Object) { break true } rescue false)
      omit_if_jruby "JRuby must enable ObjectSpace.each_object for this test"
    end

    server = create_tcp_server
    port = server.addr[1]
    h = {
      server: server,
      port: port,
      server_created: {
        server: server.inspect,
        t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
      }
    }
    net_imap = Class.new(Net::IMAP) do
      @@h = h
      def tcp_socket(host, port)
        @@h[:in_tcp_socket] = {
          host: host,
          port: port,
          server: @@h[:server].inspect,
          t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
        }
        #super
        s = Socket.tcp(host, port)
        @@h[:in_tcp_socket_2] = {
          s: s.inspect,
          local_address: s.local_address,
          remote_address: s.remote_address,
          t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
        }
        s.setsockopt(:SOL_SOCKET, :SO_KEEPALIVE, true)
        s
      end
    end
    start_server do
      begin
        h[:in_start_server_before_accept] = {
          t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
        }
        sock = server.accept
        h[:in_start_server] = {
          sock_addr: sock.addr,
          sock_peeraddr: sock.peeraddr,
          t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
          sockets: ObjectSpace.each_object(BasicSocket).map{|s| [s.inspect, connect_address: (s.connect_address rescue nil).inspect, local_address: (s.local_address rescue nil).inspect, remote_address: (s.remote_address rescue nil).inspect] },
        }
        sock.close
        h[:in_start_server_sock_closed] = {
          t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
        }
      ensure
        server.close
      end
    end
    assert_local_raise(Net::IMAP::Error) do
      #Net::IMAP.new(server_addr, :port => port)
      if true
          net_imap.new(server_addr, :port => port)
      else
        # for testing debug print
        begin
          net_imap.new(server_addr, :port => port)
        rescue Net::IMAP::Error
          raise Errno::EINVAL
        end
      end
    rescue SystemCallError => e # for debug on OpenCSW
      h[:in_rescue] = {
        e: e,
        server_addr: server_addr,
        t: Process.clock_gettime(Process::CLOCK_MONOTONIC),
      }
      require 'pp'
      raise(PP.pp(h, +''))
    end
  end

  def test_default_port
    assert_equal(143, Net::IMAP.default_port)
    assert_equal(143, Net::IMAP.default_imap_port)
    assert_equal(993, Net::IMAP.default_tls_port)
    assert_equal(993, Net::IMAP.default_ssl_port)
    assert_equal(993, Net::IMAP.default_imaps_port)
  end

  def test_disconnect
    server = create_tcp_server
    port = server.addr[1]
    start_server do
      sock = server.accept
      begin
        sock.print("* OK test server\r\n")
        sock.gets
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0001 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = Net::IMAP.new(server_addr, :port => port)
      imap.logout
      imap.disconnect
      assert_equal(true, imap.disconnected?)
      imap.disconnect
      assert_equal(true, imap.disconnected?)
    ensure
      imap.disconnect if imap && !imap.disconnected?
    end
  end

end
