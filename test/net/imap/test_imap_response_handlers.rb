# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPResponseHandlersTest < Test::Unit::TestCase
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

  test "#add_response_handlers" do
    responses = []
    with_fake_server do |server, imap|
      server.on("NOOP") do |resp|
        3.times do resp.untagged("#{_1 + 1} EXPUNGE") end
        resp.done_ok
      end

      assert_equal 0, imap.response_handlers.length
      imap.add_response_handler do responses << [:block, _1] end
      assert_equal 1, imap.response_handlers.length
      imap.add_response_handler(->{ responses << [:proc, _1] })
      assert_equal 2, imap.response_handlers.length

      imap.noop
      assert_pattern do
        responses => [
          [:block, Net::IMAP::UntaggedResponse[name: "EXPUNGE", data: 1]],
          [:proc,  Net::IMAP::UntaggedResponse[name: "EXPUNGE", data: 1]],
          [:block, Net::IMAP::UntaggedResponse[name: "EXPUNGE", data: 2]],
          [:proc,  Net::IMAP::UntaggedResponse[name: "EXPUNGE", data: 2]],
          [:block, Net::IMAP::UntaggedResponse[name: "EXPUNGE", data: 3]],
          [:proc,  Net::IMAP::UntaggedResponse[name: "EXPUNGE", data: 3]],
        ]
      end
    end
  end

end
