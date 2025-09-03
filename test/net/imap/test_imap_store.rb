# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPStoreTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  test "#store with FETCH responses" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("STORE") do |resp|
        resp.untagged("123 FETCH (UID 1111 FLAGS (\\Seen $MDNSent))")
        resp.untagged("456 FETCH (UID 4444 FLAGS (\\Seen \\Answered))")
        resp.untagged("789 FETCH (UID 7777 FLAGS (\\Seen))")
        resp.done_ok
      end
      changed = imap.store [123, 456, 789], "+FLAGS", %i[Seen]
      assert_equal("RUBY0002 STORE 123,456,789 +FLAGS (\\Seen)",
                   server.commands.pop.raw.strip)
      assert_equal 3, changed.size
      assert_instance_of Net::IMAP::FetchData, changed[0]
      assert_instance_of Net::IMAP::FetchData, changed[1]
      assert_instance_of Net::IMAP::FetchData, changed[2]
      assert_equal 123,  changed[0].seqno
      assert_equal 456,  changed[1].seqno
      assert_equal 789,  changed[2].seqno
      assert_equal 1111, changed[0].uid
      assert_equal 4444, changed[1].uid
      assert_equal 7777, changed[2].uid
      assert_equal [:Seen, "$MDNSent"], changed[0].flags
      assert_equal [:Seen, :Answered],  changed[1].flags
      assert_equal [:Seen],             changed[2].flags
    end
  end

  test "#uid_store with UIDFETCH responses" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("UID STORE") do |resp|
        resp.untagged("1111 UIDFETCH (FLAGS (\\Seen $MDNSent))")
        resp.untagged("4444 UIDFETCH (FLAGS (\\Seen \\Answered))")
        resp.untagged("7777 UIDFETCH (FLAGS (\\Seen))")
        resp.done_ok
      end
      changed = imap.uid_store [123, 456, 789], "+FLAGS", %i[Seen]
      assert_equal("RUBY0002 UID STORE 123,456,789 +FLAGS (\\Seen)",
                   server.commands.pop.raw.strip)
      assert_equal 3, changed.size
      assert_instance_of Net::IMAP::UIDFetchData, changed[0]
      assert_instance_of Net::IMAP::UIDFetchData, changed[1]
      assert_instance_of Net::IMAP::UIDFetchData, changed[2]
      assert_equal 1111, changed[0].uid
      assert_equal 4444, changed[1].uid
      assert_equal 7777, changed[2].uid
      assert_equal [:Seen, "$MDNSent"], changed[0].flags
      assert_equal [:Seen, :Answered],  changed[1].flags
      assert_equal [:Seen],             changed[2].flags
    end
  end

  test "#store with unchangedsince" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("STORE", &:done_ok)
      imap.store 1..-1, "FLAGS", %i[Deleted], unchangedsince: 12345
      assert_equal(
        "RUBY0002 STORE 1:* (UNCHANGEDSINCE 12345) FLAGS (\\Deleted)",
        server.commands.pop.raw.strip
      )
    end
  end

  test "#uid_store with changedsince" do
    with_fake_server select: "inbox" do |server, imap|
      server.on("UID STORE", &:done_ok)
      imap.uid_store 1..-1, "FLAGS", %i[Deleted], unchangedsince: 987
      assert_equal(
        "RUBY0002 UID STORE 1:* (UNCHANGEDSINCE 987) FLAGS (\\Deleted)",
        server.commands.pop.raw.strip
      )
    end
  end

end
