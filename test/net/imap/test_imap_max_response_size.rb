# frozen_string_literal: true

require "net/imap"
require "test/unit"

class IMAPMaxResponseSizeTest < Test::Unit::TestCase

  def setup
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

  test "#max_response_size reading literals" do
    _, port = with_server_socket do |sock|
      sock.gets # => NOOP
      sock.print("RUBY0001 OK done\r\n")
      sock.gets # => NOOP
      sock.print("* 1 FETCH (BODY[] {12345}\r\n" + "a" * 12_345 + ")\r\n")
      sock.print("RUBY0002 OK done\r\n")
      "RUBY0003"
    end
    Timeout.timeout(5) do
      imap = Net::IMAP.new("localhost", port: port, max_response_size: 640 << 20)
      assert_equal 640 << 20, imap.max_response_size
      imap.max_response_size = 12_345 + 30
      assert_equal 12_345 + 30, imap.max_response_size
      imap.noop # to reset the get_response limit
      imap.noop # to send the FETCH
      assert_equal "a" * 12_345, imap.responses["FETCH"].first.attr["BODY[]"]
    ensure
      imap.logout rescue nil
      imap.disconnect rescue nil
    end
  end

  test "#max_response_size closes connection for too long line" do
    _, port = with_server_socket do |sock|
      sock.gets or next # => never called
      fail "client disconnects first"
    end
    assert_raise_with_message(
      Net::IMAP::ResponseTooLargeError, /exceeds max_response_size .*\b10B\b/
    ) do
      Net::IMAP.new("localhost", port: port, max_response_size: 10)
      fail "should not get here (greeting longer than max_response_size)"
    end
  end

  test "#max_response_size closes connection for too long literal" do
    _, port = with_server_socket(ignore_io_error: true) do |sock|
      sock.gets # => NOOP
      sock.print "* 1 FETCH (BODY[] {1000}\r\n" + "a" * 1000 + ")\r\n"
      sock.print("RUBY0001 OK done\r\n")
    end
    client = Net::IMAP.new("localhost", port: port, max_response_size: 1000)
    assert_equal 1000, client.max_response_size
    client.max_response_size = 50
    assert_equal 50, client.max_response_size
    assert_raise_with_message(
      Net::IMAP::ResponseTooLargeError,
      /\d+B read \+ 1000B literal.* exceeds max_response_size .*\b50B\b/
    ) do
      client.noop
      fail "should not get here (FETCH literal longer than max_response_size)"
    end
  end

  def with_server_socket(ignore_io_error: false)
    server = create_tcp_server
    port   = server.addr[1]
    start_server do
      Timeout.timeout(5) do
        sock = server.accept
        sock.print("* OK connection established\r\n")
        logout_tag = yield sock if block_given?
        sock.gets # => LOGOUT
        sock.print("* BYE terminating connection\r\n")
        sock.print("#{logout_tag} OK LOGOUT completed\r\n") if logout_tag
      rescue IOError, EOFError, Errno::ECONNABORTED, Errno::ECONNRESET,
        Errno::EPIPE, Errno::ETIMEDOUT
        ignore_io_error or raise
      ensure
        sock.close rescue nil
        server.close rescue nil
      end
    end
    return server, port
  end

  def start_server
    th = Thread.new do
      yield
    end
    @threads << th
    sleep 0.1 until th.stop?
  end

  def create_tcp_server
    return TCPServer.new(server_addr, 0)
  end

  def server_addr
    Addrinfo.tcp("localhost", 0).ip_address
  end
end
