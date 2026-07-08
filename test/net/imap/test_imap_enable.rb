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

      assert_equal Set.new, imap.enabled
      refute imap.enabled?("condstore")
      refute imap.enabled?(:utf8)
      refute imap.utf8_enabled?

      enabled = imap.enable(%w[CONDSTORE x-pig-latin])
      assert_equal "RUBY0001 ENABLE CONDSTORE x-pig-latin", cmdq.pop.raw.strip
      assert_equal %w[CONDSTORE], enabled
      assert_equal Set.new(%w[CONDSTORE]), imap.enabled
      assert imap.enabled?("condstore")
      assert imap.enabled?("CondStore")
      refute imap.enabled?("x-pig-latin")
      refute imap.enabled?(:utf8)
      refute imap.utf8_enabled?

      enabled = imap.enable(:utf8, "condstore QResync")
      assert_equal("RUBY0002 ENABLE UTF8=ACCEPT condstore QResync",
                   cmdq.pop.raw.strip)
      assert_equal %w[UTF8=ACCEPT], enabled
      assert_equal Set.new(%w[CONDSTORE UTF8=ACCEPT]), imap.enabled
      assert imap.enabled?(:utf8)
      assert imap.enabled?("UTF8=accept")
      refute imap.enabled?("IMAP4rev2")
      assert imap.utf8_enabled?

      assert_empty cmdq

      assert_raise(Net::IMAP::DataFormatError) do
        imap.enable "injection\r\ninjected logout"
      end
      assert_empty cmdq
      assert_raise(Net::IMAP::DataFormatError) do
        imap.enable "foo", "", "bar"
      end
    end
  end

  test("enable IMAP4rev2") do
    with_fake_server(
      with_extensions: %i[ENABLE CONDSTORE IMAP4rev2 UTF8=ACCEPT],
      capabilities_enablable: %w[CONDSTORE UTF8=ACCEPT IMAP4rev2]
    ) do |server, imap|
      cmdq = server.commands

      enabled = imap.enable("IMAP4rev2")
      assert_equal "RUBY0001 ENABLE IMAP4rev2", cmdq.pop.raw.strip
      assert_equal %w[IMAP4REV2], enabled
      assert_equal Set.new(%w[IMAP4REV2]), imap.enabled
      assert imap.utf8_enabled?

      assert_empty cmdq
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
