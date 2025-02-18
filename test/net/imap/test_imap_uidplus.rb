
# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPUIDPlusTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  def test_uidplus_appenduid
    with_fake_server(select: "INBOX",
                     extensions: %i[UIDPLUS]) do |server, imap|
      server.on "APPEND" do |cmd|
        cmd.done_ok code: "APPENDUID 38505 3955"
      end
      resp = imap.append("inbox", <<~EOF.gsub(/\n/, "\r\n"), [:Seen], Time.now)
        Subject: hello
        From: shugo@ruby-lang.org
        To: shugo@ruby-lang.org

        hello world
      EOF
      code = resp.data.code
      assert_equal("APPENDUID", code.name)
      assert_equal(38505,       code.data.uidvalidity)
      assert_equal([3955],      code.data.assigned_uids.numbers)
      assert_equal "APPEND", server.commands.pop.name
    end
  end

  def test_uidplus_copyuid_multiple
    with_fake_server(select: "INBOX",
                     extensions: %i[UIDPLUS]) do |server, imap|
      server.on "UID COPY" do |cmd|
        cmd.done_ok code: "COPYUID 38505 3955,3960:3962 3963:3966"
      end
      resp = imap.uid_copy([3955,3960..3962], 'trash')
      code = resp.data.code
      cmd  = server.commands.pop
      assert_equal(["UID COPY", "3955,3960:3962 trash"], [cmd.name, cmd.args])
      assert_equal("COPYUID", code.name)
      assert_equal(38505, code.data.uidvalidity)
      assert_equal([3955, 3960, 3961, 3962], code.data.source_uids.numbers)
      assert_equal([3963, 3964, 3965, 3966], code.data.assigned_uids.numbers)
    end
  end

  def test_uidplus_copyuid_single
    with_fake_server(select: "INBOX",
                     extensions: %i[UIDPLUS]) do |server, imap|
      server.on "UID COPY" do |cmd|
        cmd.done_ok code: "COPYUID 38505 3955 3967"
      end
      resp = imap.uid_copy(3955, 'trash')
      code = resp.data.code
      cmd  = server.commands.pop
      assert_equal(["UID COPY", "3955 trash"], [cmd.name, cmd.args])
      assert_equal("COPYUID", code.name)
      assert_equal(38505, code.data.uidvalidity)
      assert_equal([3955], code.data.source_uids.numbers)
      assert_equal([3967], code.data.assigned_uids.numbers)
    end
  end

  def test_uidplus_uidnotsticky
    with_fake_server(extensions: %i[UIDPLUS]) do |server, imap|
      server.config.mailboxes["trash"] = { uidnotsticky: true }
      imap.select('trash')
      assert imap.responses("NO", &:to_a).any? {
        _1.code == Net::IMAP::ResponseCode.new('UIDNOTSTICKY', nil)
      }
    end
  end

end
