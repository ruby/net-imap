# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPSocketReadLimitTest < Test::Unit::TestCase
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

  def setup_various_responses_on_noop(server)
    server.on("NOOP") do |resp|
      # 10 byte response (prefix: "* ", suffix: "\r\n")
      resp.untagged("OK 678")
      # 20 byte response (prefix: "* ", suffix: "\r\n")
      resp.untagged("OK 6789012345678")
      # 21 byte response (prefix: "* ", suffix: "\r\n")
      resp.untagged("OK 67890123456789")
      # 22 byte response (prefix: "* ", suffix: "\r\n")
      resp.untagged("OK 678901234567890")
      # very large literal
      resp.untagged("1 FETCH (BODY[] {12345}\r\n" + "a" * 12_345 + ")")
      resp.done_ok
    end
  end

  def setup_illegal_CRs_response_on_noop(server)
    # response with many illegal CR chars (not followed by LF)
    server.on("NOOP") do |resp|
      resp.untagged("OK #{"\r" * 50} Oops!")
      resp.done_ok
    end
  end

  data " 1b",    1
  data " 2b",    2
  data " 9b",    9
  data "10b",   10
  data "20b",   20
  data "21b",   21
  data "22b",   22
  data " 1KiB",  1 << 10
  data "16KiB", 16 << 10
  data "16MiB", 16 << 20
  data "nil",   nil
  test "#config.socket_read_limit" do |limit|
    Net::IMAP.config.max_response_size = nil
    Net::IMAP.config.socket_read_limit = limit
    with_fake_server do |server, imap|
      setup_various_responses_on_noop(server)
      responses = []
      imap.add_response_handler do
        responses << _1.data if _1 in Net::IMAP::UntaggedResponse
      end

      imap.noop
      assert_equal 5, responses.count
      assert_equal "678",             responses[0].text
      assert_equal "6789012345678",   responses[1].text
      assert_equal "67890123456789",  responses[2].text
      assert_equal "678901234567890", responses[3].text
      assert_equal "a" * 12_345,      responses[4].message
    end

    with_fake_server(ignore_io_error: true) do |server, imap|
      setup_illegal_CRs_response_on_noop(server)
      # ResponseParseError means it was successfully sent to the parser
      assert_raise(Net::IMAP::ResponseParseError) do
        imap.noop
      end
    end
  end

  test "#config.socket_read_limit <= zero" do
    with_fake_server(ignore_io_error: true) do |server, imap|
      imap.config.socket_read_limit = 0
      assert_raise(Net::IMAP::SocketReadLimitError) do
        imap.noop
      end
    end
    with_fake_server(ignore_io_error: true) do |server, imap|
      imap.config.socket_read_limit = -1
      assert_raise(Net::IMAP::SocketReadLimitError) do
        imap.noop
      end
    end
  end

end
