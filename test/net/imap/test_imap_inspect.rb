# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPInspectTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  test "#inspect for every connection state" do
    with_fake_server(preauth: false) do |server, imap|
      prefix = "Net::IMAP:0x%s %s:%s" % [
        "%08x" % imap.__id__, # NOTE: this is different from `super`
        imap.host,
        imap.port,
      ]
      assert_equal "#<#{prefix} PLAINTEXT not_authenticated>",
                   imap.inspect
      # AUTHENTICATE, SELECT, CLOSE
      imap.authenticate :plain, "test_user", "test-password"
      assert_equal "#<#{prefix} PLAINTEXT authenticated>",
                   imap.inspect
      # TODO: assert_equal("#<#{prefix} authenticated authid=\"test_user\">",
      # TODO:              imap.inspect)
      imap.select "INBOX"
      assert_equal "#<#{prefix} PLAINTEXT selected>",
                   imap.inspect
      # TODO: assert_equal "#<#{prefix} selected authid=\"test_user\" " \
      # TODO:              "mailbox=\"INBOX\" uidvalidity=#{uidvalidity})>",
      # TODO:              imap.inspect
      imap.close
      assert_equal "#<#{prefix} PLAINTEXT authenticated>",
                   imap.inspect
      imap.logout
      assert_equal "#<#{prefix} PLAINTEXT logout>",
                   imap.inspect
      imap.disconnect
      assert_equal "#<#{prefix} PLAINTEXT disconnected>",
                   imap.inspect
    end
  end

end
