# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPEnableTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  def test_enable
    with_fake_server(
      with_extensions: %i[ENABLE CONDSTORE UTF8=ACCEPT],
      capabilities_enablable: %w[CONDSTORE UTF8=ACCEPT]
    ) do |server, imap|
      cmdq = server.commands

      result1 = imap.enable(%w[CONDSTORE x-pig-latin])
      result2 = imap.enable(:utf8, "condstore QResync")
      result3 = imap.enable(:utf8, "UTF8=ACCEPT", "UTF8=ONLY")
      cmd1, cmd2, cmd3 = Array.new(3) { cmdq.pop.raw.strip }

      assert_equal "RUBY0001 ENABLE CONDSTORE x-pig-latin",         cmd1
      assert_equal "RUBY0002 ENABLE UTF8=ACCEPT condstore QResync", cmd2
      assert_equal "RUBY0003 ENABLE UTF8=ACCEPT",                   cmd3
      assert_empty cmdq

      assert_equal %w[CONDSTORE],   result1
      assert_equal %w[UTF8=ACCEPT], result2
      assert_equal [],              result3
    end
  end

  test("missing server ENABLED response") do
    with_fake_server do |server, imap|
      server.on "ENABLE", &:done_ok
      enabled = imap.enable "foo", "bar", "baz"
      assert_equal [], enabled
    end
  end

end
