# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPQuotaTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  test "#setquota(quota_root, limit)" do
    with_fake_server do |server, imap|
      server.on "SETQUOTA", &:done_ok

      # integer arg
      imap.setquota "INBOX", 512
      rcvd_cmd = server.commands.pop
      assert_equal "SETQUOTA",            rcvd_cmd.name
      assert_equal "INBOX (STORAGE 512)", rcvd_cmd.args

      # string arg
      imap.setquota "INBOX", "512"
      rcvd_cmd = server.commands.pop
      assert_equal "SETQUOTA",            rcvd_cmd.name
      assert_equal "INBOX (STORAGE 512)", rcvd_cmd.args

      # empty quota root, null limit
      imap.setquota "", nil
      rcvd_cmd = server.commands.pop
      assert_equal "SETQUOTA",            rcvd_cmd.name
      assert_equal '"" ()',               rcvd_cmd.args

      assert_raise_with_message(Net::IMAP::DataFormatError,
                                "512.0 is not a valid number64") do
        imap.setquota "INBOX", 512.0
      end
      assert_raise_with_message(Net::IMAP::DataFormatError,
                                '"512 620" is not a valid number64') do
        imap.setquota "INBOX", "512 620"
      end
    end
  end
end
