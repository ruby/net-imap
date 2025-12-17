# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPResponsesTest < Test::Unit::TestCase
  include Net::IMAP::FakeServer::TestHelper

  CONFIG_OPTIONS = %i[
    silence_deprecation_warning
    warn
    raise
  ].freeze

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

  def for_each_config_option(imap)
    original = imap.config.responses_without_block
    CONFIG_OPTIONS.each do |option|
      imap.config.responses_without_block = option
      yield option
    end
  ensure
    imap.config.responses_without_block = original
  end

  # with a block: returns the block result
  test "#responses(&block)" do
    with_fake_server do |server, imap|
      stderr = EnvUtil.verbose_warning do
        # Config options make no difference to responses(&block)
        for_each_config_option(imap) do
          # responses available before SELECT/EXAMINE
          assert_equal(%w[IMAP4REV1 NAMESPACE MOVE IDLE UTF8=ACCEPT],
                       imap.responses { _1["CAPABILITY"].last })
        end
        # responses are cleared after SELECT/EXAMINE
        imap.select "INBOX"
        for_each_config_option(imap) do
          assert_equal nil,          imap.responses { _1["CAPABILITY"].last }
          assert_equal [172],        imap.responses { _1["EXISTS"].dup }
          assert_equal [3857529045], imap.responses { _1["UIDVALIDITY"].dup }
          assert_equal 1,            imap.responses { _1["RECENT"].last }
          assert_equal(%i[Answered Flagged Deleted Seen Draft],
                      imap.responses { _1["FLAGS"].last })
        end
      end
      assert_empty stderr # never warn when a block is given
    end
  end

  # with a type and a block: returns the block result
  test "#responses(type, &block)" do
    with_fake_server do |server, imap|
      stderr = EnvUtil.verbose_warning do
        # Config options make no difference to responses(type, &block)
        for_each_config_option(imap) do
          # responses available before SELECT/EXAMINE
          assert_equal(%w[IMAP4REV1 NAMESPACE MOVE IDLE UTF8=ACCEPT],
                       imap.responses("CAPABILITY", &:last))
        end
        # responses are cleared after SELECT/EXAMINE
        imap.select "INBOX"
        for_each_config_option(imap) do
          assert_equal nil,          imap.responses("CAPABILITY", &:last)
          assert_equal [172],        imap.responses("EXISTS", &:dup)
          assert_equal [3857529045], imap.responses("UIDVALIDITY", &:dup)
          assert_equal 1, imap.responses("RECENT", &:last)
          assert_equal [4392], imap.responses("UIDNEXT", &:dup)
          assert_equal(%i[Answered Flagged Deleted Seen Draft],
                       imap.responses("FLAGS", &:last))
        end
      end
      assert_empty stderr # never warn when type or block are given
    end
  end

  # with with a type and no block: always returns a frozen duplicate
  test "#responses(type, &nil)" do
    with_fake_server do |server, imap|
      stderr = EnvUtil.verbose_warning do
        # Config options make no difference to responses(type)
        for_each_config_option(imap) do
          # responses available before SELECT/EXAMINE
          assert imap.responses("CAPABILITY").frozen?
          assert_equal(%w[IMAP4REV1 NAMESPACE MOVE IDLE UTF8=ACCEPT],
                       imap.responses("CAPABILITY").last)
        end
        # responses are cleared after SELECT/EXAMINE
        imap.select "INBOX"
        for_each_config_option(imap) do
          assert imap.responses("CAPABILITY").frozen?
          assert imap.responses("EXISTS").frozen?
          assert imap.responses("UIDVALIDITIY").frozen?
          assert_equal [],           imap.responses("CAPABILITY")
          assert_equal [172],        imap.responses("EXISTS")
          assert_equal [3857529045], imap.responses("UIDVALIDITY")
          assert_equal 1, imap.responses("RECENT").last
          assert imap.responses("UIDNEXT").frozen?
          assert_equal [4392], imap.responses("UIDNEXT")
          assert imap.responses("FLAGS").frozen?
          assert_equal(%i[Answered Flagged Deleted Seen Draft],
                       imap.responses("FLAGS").last)
        end
      end
      assert_empty stderr # never warn when type is given
    end
  end

  def assert_responses_warn
    assert_warn(
      /
        (?=(?-x)Pass a type or block to #responses\b)
        (?=.*config\.responses_without_block.*:silence_deprecation_warning\b)
        (?=.*\#extract_responses\b)
           .*\#clear_responses\b
      /ix
    ) do
      yield
    end
  end

  # without type or block: relies on config.responses_without_block
  test "#responses without type or block" do
    with_fake_server do |server, imap|
      # can be configured to raise
      imap.config.responses_without_block = :raise
      assert_raise(ArgumentError) do imap.responses end
      # with warnings (default for v0.5)
      imap.config.responses_without_block = :warn
      assert_responses_warn do assert_kind_of Hash, imap.responses end
      assert_responses_warn do refute imap.responses.frozen? end
      assert_responses_warn do refute imap.responses["CAPABILITY"].frozen? end
      assert_responses_warn do
        assert_equal(%w[IMAP4REV1 NAMESPACE MOVE IDLE UTF8=ACCEPT],
                     imap.responses["CAPABILITY"].last)
      end
      assert_responses_warn do imap.responses["FAKE"] = :uh_oh! end
      assert_responses_warn do assert_equal :uh_oh!, imap.responses["FAKE"] end
      assert_responses_warn do imap.responses.delete("FAKE") end
      assert_responses_warn do assert_equal [], imap.responses["FAKE"] end
      # warnings can be silenced
      imap.config.responses_without_block = :silence_deprecation_warning
      stderr = EnvUtil.verbose_warning do
        refute imap.responses.frozen?
        refute imap.responses["CAPABILITY"].frozen?
        assert_equal(%w[IMAP4REV1 NAMESPACE MOVE IDLE UTF8=ACCEPT],
                     imap.responses["CAPABILITY"].last)
        imap.responses["FAKE"] = :uh_oh!
        assert_equal :uh_oh!, imap.responses["FAKE"]
        imap.responses.delete("FAKE")
        assert_equal [], imap.responses["FAKE"]
      end
      assert_empty stderr
      # default behavior since 0.6.0
      imap.config.responses_without_block = :frozen_dup
      stderr = EnvUtil.verbose_warning do
        assert imap.responses.frozen?
        assert imap.responses["CAPABILITY"].frozen?
        assert_equal(%w[IMAP4REV1 NAMESPACE MOVE IDLE UTF8=ACCEPT],
                     imap.responses["CAPABILITY"].last)
        imap.responses do |r|
          refute r.frozen?
          refute r.values.any?(&:frozen?)
        end
      end
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
