# frozen_string_literal: true

require "net/imap"
require "test/unit"

class IMAPResponseHandlersTest < Test::Unit::TestCase

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

  test "#add_response_handlers" do
    server = create_tcp_server
    port   = server.addr[1]
    start_server do
      sock = server.accept
      Timeout.timeout(5) do
        sock.print("* OK connection established\r\n")
        sock.gets # => NOOP
        sock.print("* 1 EXPUNGE\r\n")
        sock.print("* 2 EXPUNGE\r\n")
        sock.print("* 3 EXPUNGE\r\n")
        sock.print("RUBY0001 OK NOOP completed\r\n")
        sock.gets # => LOGOUT
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0002 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      responses = []
      imap = Net::IMAP.new(server_addr, port: port)
      assert_equal 0, imap.response_handlers.length
      imap.add_response_handler do |r| responses << [:block, r] end
      assert_equal 1, imap.response_handlers.length
      imap.add_response_handler(->(r) { responses << [:proc, r] })
      assert_equal 2, imap.response_handlers.length

      imap.noop
      responses = responses[0, 6].map {|which, resp|
        [which, resp.class, resp.name, resp.data]
      }
      assert_equal [
        [:block, Net::IMAP::UntaggedResponse, "EXPUNGE", 1],
        [:proc,  Net::IMAP::UntaggedResponse, "EXPUNGE", 1],
        [:block, Net::IMAP::UntaggedResponse, "EXPUNGE", 2],
        [:proc,  Net::IMAP::UntaggedResponse, "EXPUNGE", 2],
        [:block, Net::IMAP::UntaggedResponse, "EXPUNGE", 3],
        [:proc,  Net::IMAP::UntaggedResponse, "EXPUNGE", 3],
      ], responses
    ensure
      imap&.logout
      imap&.disconnect
    end
  end

  test "::new with response_handlers kwarg" do
    greeting = nil
    expunges = []
    alerts   = []
    untagged = 0
    handler0 = ->(r) { greeting ||= r }
    handler1 = ->(r) { alerts   << r.data.text if r.data.code.name == "ALERT" rescue nil }
    handler2 = ->(r) { expunges << r.data if r.name == "EXPUNGE" }
    handler3 = ->(r) { untagged += 1 if r.is_a?(Net::IMAP::UntaggedResponse) }
    response_handlers = [handler0, handler1, handler2, handler3]

    server = create_tcp_server
    port   = server.addr[1]
    start_server do
      sock = server.accept
      Timeout.timeout(5) do
        sock.print("* OK connection established\r\n")
        sock.gets # => NOOP
        sock.print("* 1 EXPUNGE\r\n")
        sock.print("* 1 EXPUNGE\r\n")
        sock.print("* OK [ALERT] The first alert.\r\n")
        sock.print("RUBY0001 OK [ALERT] Did you see the alert?\r\n")
        sock.gets # => LOGOUT
        sock.print("* BYE terminating connection\r\n")
        sock.print("RUBY0002 OK LOGOUT completed\r\n")
      ensure
        sock.close
        server.close
      end
    end
    begin
      imap = Net::IMAP.new("localhost", port: port,
                           response_handlers: response_handlers)
      assert_equal response_handlers, imap.response_handlers
      refute_same  response_handlers, imap.response_handlers

      # handler0 recieved the greeting and handler3 counted it
      assert_equal imap.greeting, greeting
      assert_equal 1, untagged

      imap.noop
      assert_equal 4, untagged
      assert_equal [1, 1], expunges # from handler2
      assert_equal ["The first alert.", "Did you see the alert?"], alerts
    ensure
      imap&.logout
      imap&.disconnect
    end
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
