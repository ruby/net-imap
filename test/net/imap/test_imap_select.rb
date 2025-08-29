# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPSelectTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  test "#select with condstore" do
    with_fake_server do |server, imap|
      imap.select "inbox", condstore: true
      assert_equal("RUBY0001 SELECT inbox (CONDSTORE)",
                   server.commands.pop.raw.strip)
    end
  end

  test "#examine with condstore" do
    with_fake_server do |server, imap|
      imap.examine "inbox", condstore: true
      assert_equal("RUBY0001 EXAMINE inbox (CONDSTORE)",
                   server.commands.pop.raw.strip)
    end
  end

end
