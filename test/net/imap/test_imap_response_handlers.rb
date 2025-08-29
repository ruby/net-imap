# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPResponseHandlersTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

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

  test "::new with response_handlers kwarg" do
    greeting = nil
    expunges = []
    alerts   = []
    untagged = 0
    handler0 = ->{ greeting ||= _1 }
    handler1 = ->{ alerts   << _1.data.text if _1 in {data: {code: {name: "ALERT"}}} }
    handler2 = ->{ expunges << _1.data if _1 in {name: "EXPUNGE"} }
    handler3 = ->{ untagged += 1 if _1.is_a?(Net::IMAP::UntaggedResponse) }
    response_handlers = [handler0, handler1, handler2, handler3]

    run_fake_server_in_thread do |server|
      port = server.port
      imap = Net::IMAP.new("localhost", port:, response_handlers:)
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
