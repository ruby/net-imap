# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPMaxResponseSizeTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  test "#max_response_size reading literals" do
    with_fake_server(preauth: true) do |server, imap|
      imap.max_response_size = 12_345 + 30
      server.on("NOOP") do |resp|
        resp.untagged("1 FETCH (BODY[] {12345}\r\n" + "a" * 12_345 + ")")
        resp.done_ok
      end
      imap.noop
      assert_equal "a" * 12_345, imap.responses("FETCH").first.message
    end
  end

  test "#max_response_size closes connection for too long line" do
    Net::IMAP.config.max_response_size = 10
    run_fake_server_in_thread(preauth: false, ignore_io_error: true) do |server|
      assert_raise_with_message(
        Net::IMAP::ResponseTooLargeError, /exceeds max_response_size .*\b10B\b/
      ) do
        with_client("localhost", port: server.port) do
          fail "should not get here (greeting longer than max_response_size)"
        end
      end
    end
  end

  test "#max_response_size closes connection for too long literal" do
    Net::IMAP.config.max_response_size = 1<<20
    with_fake_server(preauth: false, ignore_io_error: true) do |server, client|
      client.max_response_size = 50
      server.on("NOOP") do |resp|
        resp.untagged("1 FETCH (BODY[] {1000}\r\n" + "a" * 1000 + ")")
      end
      assert_raise_with_message(
        Net::IMAP::ResponseTooLargeError,
        /\d+B read \+ 1000B literal.* exceeds max_response_size .*\b50B\b/
      ) do
        client.noop
        fail "should not get here (FETCH literal longer than max_response_size)"
      end
    end
  end

end
