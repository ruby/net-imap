# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPSelectTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  def test_close
    with_fake_server(select: "inbox") do |server, imap|
      resp = imap.close
      assert_equal("RUBY0002 CLOSE", server.commands.pop.raw.strip)
      assert_equal([Net::IMAP::TaggedResponse, "RUBY0002", "OK"],
                   [resp.class, resp.tag, resp.name])
      assert_empty server.commands
    end
  end

  def test_unselect
    with_fake_server(select: "inbox") do |server, imap|
      resp = imap.unselect
      sent = server.commands.pop
      assert_equal(["UNSELECT", nil], [sent.name, sent.args])
      assert_equal([Net::IMAP::TaggedResponse, "RUBY0002", "OK"],
                   [resp.class, resp.tag, resp.name])
      assert_empty server.commands
    end
  end

end
