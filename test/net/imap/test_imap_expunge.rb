# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPExpungeTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  test "#expunge with EXPUNGE responses" do
    with_fake_server(select: "INBOX") do |server, imap|
      server.on "EXPUNGE" do |resp|
        resp.untagged("1 EXPUNGE")
        resp.untagged("1 EXPUNGE")
        resp.untagged("99 EXPUNGE")
        resp.done_ok
      end
      response = imap.expunge
      cmd = server.commands.pop
      assert_equal ["EXPUNGE", nil], [cmd.name, cmd.args]
      assert_equal [1, 1, 99], response
      assert_equal [], imap.clear_responses("EXPUNGED")
    end
  end

  test "#expunge with a VANISHED response" do
    with_fake_server(select: "INBOX") do |server, imap|
      server.on "EXPUNGE" do |resp|
        resp.untagged("VANISHED 15:456")
        resp.done_ok
      end
      response = imap.expunge
      cmd = server.commands.pop
      assert_equal ["EXPUNGE", nil], [cmd.name, cmd.args]
      assert_equal(
        Net::IMAP::VanishedData[uids: [15..456], earlier: false],
        response
      )
      assert_equal([], imap.clear_responses("VANISHED"))
    end
  end

  test "#expunge with multiple VANISHED responses" do
    with_fake_server(select: "INBOX") do |server, imap|
      server.unsolicited("VANISHED 86")
      server.on "EXPUNGE" do |resp|
        resp.untagged("VANISHED (EARLIER) 1:5,99,123")
        resp.untagged("VANISHED 15,456")
        resp.untagged("VANISHED (EARLIER) 987,1001")
        resp.done_ok
      end
      response = imap.expunge
      cmd = server.commands.pop
      assert_equal ["EXPUNGE", nil], [cmd.name, cmd.args]
      assert_equal(
        Net::IMAP::VanishedData[uids: [15, 86, 456], earlier: false],
        response
      )
      assert_equal(
        [
          Net::IMAP::VanishedData[uids: [1..5, 99, 123], earlier: true],
          Net::IMAP::VanishedData[uids: [987, 1001],     earlier: true],
        ],
        imap.clear_responses("VANISHED")
      )
    end
  end

  test "#uid_expunge with EXPUNGE responses" do
    with_fake_server(select: "INBOX",
                     extensions: %i[UIDPLUS]) do |server, imap|
      server.on "UID EXPUNGE" do |resp|
        resp.untagged("1 EXPUNGE")
        resp.untagged("1 EXPUNGE")
        resp.untagged("1 EXPUNGE")
        resp.done_ok
      end
      response = imap.uid_expunge(1000..1003)
      cmd = server.commands.pop
      assert_equal ["UID EXPUNGE", "1000:1003"], [cmd.name, cmd.args]
      assert_equal(response, [1, 1, 1])
    end
  end

  test "#uid_expunge with VANISHED response" do
    with_fake_server(select: "INBOX",
                     extensions: %i[UIDPLUS]) do |server, imap|
      server.on "UID EXPUNGE" do |resp|
        resp.untagged("VANISHED 1001,1003")
        resp.done_ok
      end
      response = imap.uid_expunge(1000..1003)
      cmd = server.commands.pop
      assert_equal ["UID EXPUNGE", "1000:1003"], [cmd.name, cmd.args]
      assert_equal(
        Net::IMAP::VanishedData[uids: [1001, 1003], earlier: false],
        response
      )
      assert_equal([], imap.clear_responses("VANISHED"))
    end
  end

end
