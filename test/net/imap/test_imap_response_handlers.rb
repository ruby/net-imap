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
    end
  end

  test "::new with response_handlers kwarg" do
    greeting = nil
    expunges = []
    alerts   = []
    untagged = 0
    handler0 = ->{ greeting ||= _1 }
    handler1 = ->(r) { alerts   << r.data.text if r.data.code.name == "ALERT" rescue nil }
    handler2 = ->(r) { expunges << r.data if r.name == "EXPUNGE" }
    handler3 = ->(r) { untagged += 1 if r.is_a?(Net::IMAP::UntaggedResponse) }
    response_handlers = [handler0, handler1, handler2, handler3]

    run_fake_server_in_thread do |server|
      port = server.port
      imap = Net::IMAP.new("localhost", port: port,
                           response_handlers: response_handlers)
      assert_equal response_handlers, imap.response_handlers
      refute_same  response_handlers, imap.response_handlers

      # handler0 recieved the greeting and handler3 counted it
      assert_equal imap.greeting, greeting
      assert_equal 1, untagged

      server.on("NOOP") do |resp|
        resp.untagged "1 EXPUNGE"
        resp.untagged "1 EXPUNGE"
        resp.untagged "OK [ALERT] The first alert."
        resp.done_ok  "[ALERT] Did you see the alert?"
      end

      imap.noop
      assert_equal 4, untagged
      assert_equal [1, 1], expunges # from handler2
      assert_equal ["The first alert.", "Did you see the alert?"], alerts
    ensure
      imap&.logout! unless imap&.disconnected?
    end
  end

end
