# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPFetchTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  test "argument errors" do
    with_fake_server select: "inbox" do |_, imap|
      assert_raise_with_message(ArgumentError, /\Apartial.*uid_fetch/) do
        imap.fetch(1, "FAST", partial: 1..10)
      end
    end
  end

  test "#fetch with FETCH responses" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("FETCH") do |resp|
        resp.untagged("123 FETCH (UID 1111 FLAGS (\\Seen $MDNSent))")
        resp.untagged("456 FETCH (UID 4444 FLAGS (\\Seen \\Answered))")
        resp.untagged("789 FETCH (UID 7777 FLAGS ())")
        resp.done_ok
      end
      fetched = imap.fetch [123, 456, 789], %w[UID FLAGS]
      assert_equal 3, fetched.size
      assert_instance_of Net::IMAP::FetchData, fetched[0]
      assert_instance_of Net::IMAP::FetchData, fetched[1]
      assert_instance_of Net::IMAP::FetchData, fetched[2]
      assert_equal 123,  fetched[0].seqno
      assert_equal 456,  fetched[1].seqno
      assert_equal 789,  fetched[2].seqno
      assert_equal 1111, fetched[0].uid
      assert_equal 4444, fetched[1].uid
      assert_equal 7777, fetched[2].uid
      assert_equal [:Seen, "$MDNSent"], fetched[0].flags
      assert_equal [:Seen, :Answered],  fetched[1].flags
      assert_equal [],                  fetched[2].flags
      assert_equal("RUBY0002 FETCH 123,456,789 (UID FLAGS)",
                   server.commands.pop.raw.strip)
    end
  end

  test "#uid_fetch with UIDFETCH responses" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("UID FETCH") do |resp|
        resp.untagged("1111 UIDFETCH (FLAGS (\\Seen $MDNSent))")
        resp.untagged("4444 UIDFETCH (FLAGS (\\Seen \\Answered))")
        resp.untagged("7777 UIDFETCH (FLAGS ())")
        resp.done_ok
      end
      fetched = imap.uid_fetch [123, 456, 789], %w[FLAGS]
      assert_equal 3, fetched.size
      assert_instance_of Net::IMAP::UIDFetchData, fetched[0]
      assert_instance_of Net::IMAP::UIDFetchData, fetched[1]
      assert_instance_of Net::IMAP::UIDFetchData, fetched[2]
      assert_equal 1111, fetched[0].uid
      assert_equal 4444, fetched[1].uid
      assert_equal 7777, fetched[2].uid
      assert_equal [:Seen, "$MDNSent"], fetched[0].flags
      assert_equal [:Seen, :Answered],  fetched[1].flags
      assert_equal [],                  fetched[2].flags
      assert_equal("RUBY0002 UID FETCH 123,456,789 (FLAGS)",
                   server.commands.pop.raw.strip)
    end
  end

  test "#fetch with changedsince" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("FETCH", &:done_ok)
      fetched = imap.fetch 1..-1, %w[FLAGS], changedsince: 12345
      assert_empty fetched
      assert_equal("RUBY0002 FETCH 1:* (FLAGS) (CHANGEDSINCE 12345)",
                   server.commands.pop.raw.strip)
    end
  end

  test "#uid_fetch with changedsince" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("UID FETCH", &:done_ok)
      fetched = imap.uid_fetch 1..-1, %w[FLAGS], changedsince: 12345
      assert_empty fetched
      assert_equal("RUBY0002 UID FETCH 1:* (FLAGS) (CHANGEDSINCE 12345)",
                   server.commands.pop.raw.strip)
    end
  end

  test "#uid_fetch with partial" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("UID FETCH", &:done_ok)
      imap.uid_fetch 1.., "FAST", partial: 1..500
      assert_equal("RUBY0002 UID FETCH 1:* FAST (PARTIAL 1:500)",
                   server.commands.pop.raw.strip)
      imap.uid_fetch 1.., "FAST", partial: 1...501
      assert_equal("RUBY0003 UID FETCH 1:* FAST (PARTIAL 1:500)",
                   server.commands.pop.raw.strip)
      imap.uid_fetch 1.., "FAST", partial: -500..-1
      assert_equal("RUBY0004 UID FETCH 1:* FAST (PARTIAL -500:-1)",
                   server.commands.pop.raw.strip)
      imap.uid_fetch 1.., "FAST", partial: -500...-1
      assert_equal("RUBY0005 UID FETCH 1:* FAST (PARTIAL -500:-2)",
                   server.commands.pop.raw.strip)
      imap.uid_fetch 1.., "FAST", partial: 1..20, changedsince: 1234
      assert_equal("RUBY0006 UID FETCH 1:* FAST (PARTIAL 1:20 CHANGEDSINCE 1234)",
                   server.commands.pop.raw.strip)
    end
  end

end
