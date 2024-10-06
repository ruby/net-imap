# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPResponsesTest < Test::Unit::TestCase
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

  test "#responses" do
    with_fake_server do |server, imap|
      # responses available before SELECT/EXAMINE
      assert_equal(%w[IMAP4REV1 NAMESPACE MOVE IDLE UTF8=ACCEPT],
                   imap.responses("CAPABILITY", &:last))
      resp = imap.select "INBOX"
      # responses are cleared after SELECT/EXAMINE
      assert_equal(nil, imap.responses("CAPABILITY", &:last))
      assert_equal([Net::IMAP::TaggedResponse, "RUBY0001", "OK"],
                   [resp.class, resp.tag, resp.name])
      assert_equal([172], imap.responses { _1["EXISTS"] })
      assert_equal([3857529045], imap.responses("UIDVALIDITY") { _1 })
      assert_equal(1, imap.responses("RECENT", &:last))
      assert_raise(ArgumentError) do imap.responses("UIDNEXT") end
      # Deprecated style, without a block:
      imap.config.responses_without_block = :raise
      assert_raise(ArgumentError) do imap.responses end
      imap.config.responses_without_block = :warn
      assert_raise(ArgumentError) do imap.responses("UIDNEXT") end
      assert_warn(/Pass a block.*or.*clear_responses/i) do
        assert_equal(%i[Answered Flagged Deleted Seen Draft],
                     imap.responses["FLAGS"]&.last)
      end
      # TODO: assert_no_warn?
      imap.config.responses_without_block = :silence_deprecation_warning
      assert_raise(ArgumentError) do imap.responses("UIDNEXT") end
      stderr = EnvUtil.verbose_warning {
        assert_equal(%i[Answered Flagged Deleted Seen Draft],
                     imap.responses["FLAGS"]&.last)
      }
      assert_empty stderr
    end
  end

  test "#clear_responses" do
    with_fake_server do |server, imap|
      resp = imap.select "INBOX"
      assert_equal([Net::IMAP::TaggedResponse, "RUBY0001", "OK"],
                   [resp.class, resp.tag, resp.name])
      # called with "type", clears and returns only that type
      assert_equal([172],        imap.clear_responses("EXISTS"))
      assert_equal([],           imap.clear_responses("EXISTS"))
      assert_equal([1],          imap.clear_responses("RECENT"))
      assert_equal([3857529045], imap.clear_responses("UIDVALIDITY"))
      # called without "type", clears and returns all responses
      responses = imap.clear_responses
      assert_equal([],   responses["EXISTS"])
      assert_equal([],   responses["RECENT"])
      assert_equal([],   responses["UIDVALIDITY"])
      assert_equal([12], responses["UNSEEN"])
      assert_equal([4392], responses["UIDNEXT"])
      assert_equal(5, responses["FLAGS"].last&.size)
      assert_equal(3, responses["PERMANENTFLAGS"].last&.size)
      assert_equal({}, imap.responses(&:itself))
      assert_equal({}, imap.clear_responses)
    end
  end

  test "#extract_responses" do
    with_fake_server do |server, imap|
      resp = imap.select "INBOX"
      assert_equal([Net::IMAP::TaggedResponse, "RUBY0001", "OK"],
                   [resp.class, resp.tag, resp.name])
      # Need to send a string type and a block
      assert_raise(ArgumentError) do imap.extract_responses { true } end
      assert_raise(ArgumentError) do imap.extract_responses(nil) { true } end
      assert_raise(ArgumentError) do imap.extract_responses("OK") end
      # matching nothing
      assert_equal([172], imap.responses("EXISTS", &:dup))
      assert_equal([],    imap.extract_responses("EXISTS") { String === _1 })
      assert_equal([172], imap.responses("EXISTS", &:dup))
      # matching everything
      assert_equal([172], imap.responses("EXISTS", &:dup))
      assert_equal([172], imap.extract_responses("EXISTS", &:even?))
      assert_equal([],    imap.responses("EXISTS", &:dup))
      # matching some
      server.unsolicited("101 FETCH (UID 1111 FLAGS (\\Seen))")
      server.unsolicited("102 FETCH (UID 2222 FLAGS (\\Seen \\Flagged))")
      server.unsolicited("103 FETCH (UID 3333 FLAGS (\\Deleted))")
      wait_for_response_count(imap, type: "FETCH", count: 3)

      result = imap.extract_responses("FETCH") { _1.flags.include?(:Flagged) }
      assert_equal(
        [
          Net::IMAP::FetchData.new(
            102, {"UID" => 2222, "FLAGS" => [:Seen, :Flagged]}
          ),
        ],
        result,
      )
      assert_equal 2, imap.responses("FETCH", &:count)

      result = imap.extract_responses("FETCH") { _1.flags.include?(:Deleted) }
      assert_equal(
        [Net::IMAP::FetchData.new(103, {"UID" => 3333, "FLAGS" => [:Deleted]})],
        result
      )
      assert_equal 1, imap.responses("FETCH", &:count)
    end
  end

end
