# frozen_string_literal: true

require_relative "../../lib/helper"
require_relative "fake_server"

# This file is for integration testing of command data sending, without testing
# the specifics of any particular command.
#
# For isolated unit tests of different types of command arguments, see
# test_command_data.rb.
class IMAPSendingCommandDataTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  def test_send_integer
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok

      # regular numbers may be any uint32
      assert_raise(Net::IMAP::DataFormatError) do
        imap.__send__(:send_command, "TEST", -1)
      end
      assert_empty server.commands

      imap.__send__(:send_command, "TEST", 0)
      assert_equal "0", server.commands.pop.args

      imap.__send__(:send_command, "TEST", 2**32 - 1)
      assert_equal (2**32 - 1).to_s, server.commands.pop.args

      imap.__send__(:send_command, "TEST", 2**32)
      assert_equal (2**32).to_s, server.commands.pop.args

      imap.__send__(:send_command, "TEST", 2**64 - 1)
      assert_equal (2**64 - 1).to_s, server.commands.pop.args

      assert_raise(Net::IMAP::DataFormatError) do
        imap.__send__(:send_command, "TEST", 2**64)
      end
      assert_empty server.commands
    end
  end

  def test_send_sequence_set
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok

      # SequenceSet numbers may be non-zero uint3, and -1 is translated to *
      imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(-1))
      assert_equal "*", server.commands.pop.args

      assert_raise(Net::IMAP::DataFormatError) do
        imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(0))
      end
      assert_empty server.commands

      imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(1))
      assert_equal "1", server.commands.pop.args

      imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(2**32-1))
      assert_equal (2**32 - 1).to_s, server.commands.pop.args

      assert_raise(Net::IMAP::DataFormatError) do
        imap.__send__(:send_command, "TEST", Net::IMAP::SequenceSet.new(2**32))
      end
      assert_empty server.commands
    end
  end

  def test_send_symbol_as_flag
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok

      imap.__send__(:send_command, "TEST", :Seen, :Flagged)
      assert_equal "\\Seen \\Flagged", server.commands.pop.args

      # symbol may not contain atom-specials
      [
        :"with_parens()",
        :"with_list_wildcards*",
        :"with_list_wildcards%",
        :"with_resp_special]",
        :"with\0null",
        :"with\x7fcontrol_char",
        :'"with_quoted_specials"',
        :"with_quoted_specials\\",
        :"with\rCR",
        :"with\nLF",
      ].each do |symbol|
        assert_raise_with_message(Net::IMAP::DataFormatError, /\bflag\b/i) do
          imap.__send__(:send_command, "TEST", symbol)
        end
        assert_empty server.commands
      end
    end
  end

  def test_raw_data
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok

      imap.__send__(:send_command, "TEST", Net::IMAP::RawData.new("foo bar"))
      assert_equal "foo bar", server.commands.pop.args

      imap.__send__(:send_command, "TEST",
                    Net::IMAP::RawData.new("{3}\r\nfoo"),
                    Net::IMAP::RawData.new("~{4}\r\n\0bar"))
      assert_equal "{3}\r\nfoo ~{4}\r\n\0bar", server.commands.pop.args

      # RawData must pass basic validation before sending command
      [
        "with \0 NULL",
        "with \r CR",
        "with \n LF",
        "with \r\n CRLF",
        "{1234}\r\nliteral is too small",
        "{1}\r\n\0 literal contains NULL",
      ].each do |data|
        assert_raise(Net::IMAP::DataFormatError) do
          imap.__send__(:send_command, "TEST", Net::IMAP::RawData[data:])
        end
        assert_empty server.commands
      end
    end
  end

  test("send PartialRange args") do
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok
      send_partial_ranges = ->(*args) do
        args.map! { Net::IMAP::PartialRange[_1] }
        imap.__send__(:send_command, "TEST", *args)
      end
      # simple strings
      send_partial_ranges.call "1:5", "-5:-1"
      assert_equal "1:5 -5:-1", server.commands.pop.args
      # backwards strings are reversed
      send_partial_ranges.call "5:1", "-1:-5"
      assert_equal "1:5 -5:-1", server.commands.pop.args
      # simple ranges
      send_partial_ranges.call 1..5, -5..-1
      assert_equal "1:5 -5:-1", server.commands.pop.args
      # exclusive ranges drop end
      send_partial_ranges.call 1...5, -5...-1
      assert_equal "1:4 -5:-2", server.commands.pop.args

      # backwards ranges are invalid
      assert_raise(ArgumentError) do send_partial_ranges.call( 5.. 1) end
      assert_raise(ArgumentError) do send_partial_ranges.call(-1..-5) end

      # bounds checks
      uint32_max = 2**32 - 1
      not_uint32 = 2**32
      send_partial_ranges.call 500..uint32_max
      assert_equal "500:#{uint32_max}", server.commands.pop.args
      send_partial_ranges.call 500...not_uint32
      assert_equal "500:#{uint32_max}", server.commands.pop.args
      send_partial_ranges.call "#{uint32_max}:500"
      assert_equal "500:#{uint32_max}", server.commands.pop.args

      send_partial_ranges.call(-uint32_max..-500)
      assert_equal "-#{uint32_max}:-500", server.commands.pop.args
      send_partial_ranges.call "-500:-#{uint32_max}"
      assert_equal "-#{uint32_max}:-500", server.commands.pop.args

      assert_raise(ArgumentError) do send_partial_ranges.call("foo") end
      assert_raise(ArgumentError) do send_partial_ranges.call("foo:bar") end
      assert_raise(ArgumentError) do send_partial_ranges.call("1.2:3.5") end
      assert_raise(ArgumentError) do send_partial_ranges.call("1:*") end
      assert_raise(ArgumentError) do send_partial_ranges.call("1:#{not_uint32}") end
      assert_raise(ArgumentError) do send_partial_ranges.call(1..) end
      assert_raise(ArgumentError) do send_partial_ranges.call(1..not_uint32) end
      assert_raise(ArgumentError) do send_partial_ranges.call(..1) end
    end
  end

  test "sending nil args" do
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok
      def imap.test_args(*args) = send_command("TEST", *args)

      imap.test_args nil, [nil]
      assert_equal "NIL (NIL)", server.commands.pop.args
    end
  end

  test "sending atom string args (astring-chars)" do
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok
      def imap.test_args(*args) = send_command("TEST", *args)

      imap.test_args "valid-atoms", %w[foo=bar $baz]
      assert_equal "valid-atoms (foo=bar $baz)", server.commands.pop.args

      imap.test_args "unquoted-astring", "[resp-specials]"
      assert_equal "unquoted-astring [resp-specials]", server.commands.pop.args
    end
  end

  test "string args don't allow NULL bytes" do
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok
      def imap.test_args(*args) = send_command("TEST", *args)

      assert_raise_with_message(Net::IMAP::DataFormatError, /NULL byte/) do
        imap.test_args "NULL=\0"
      end

      assert_raise_with_message(Net::IMAP::DataFormatError, /NULL byte/) do
        imap.test_args ["ok", "also ok", "not ok: \0"]
      end
    end
  end

  test "sending quoted string args" do
    with_fake_server do |server, imap|
      server.on "TEST", &:done_ok
      def imap.test_args(*args) = send_command("TEST", *args)

      imap.test_args "empty", "", [""]
      assert_equal   'empty "" ("")', server.commands.pop.args

      imap.test_args "simple-quotable-specials", "() {} %*"
      assert_equal('simple-quotable-specials "() {} %*"'.b,
                   server.commands.pop.args)

      imap.test_args "ascii-ctrl-chars", "\b\x7f"
      assert_equal("ascii-ctrl-chars \"\b\x7f\"".b, server.commands.pop.args)

      imap.test_args "quoted-specials", ["backslash=\\", 'dquotes=""']
      assert_equal('quoted-specials ("backslash=\\\\" "dquotes=\\"\\"")'.b,
                   server.commands.pop.args)
    end
  end

  test "sending UTF-8 string args" do
    with_fake_server(
      with_extensions: %w[UTF8=ACCEPT LITERAL-],
      greeting_capabilities: true,
      capabilities_enablable: %w[UTF8=ACCEPT],
    ) do |server, imap|
      server.on "TEST", &:done_ok
      def imap.test_args(*args) = send_command("TEST", *args)

      # Before enabling UTF-8 strings, with non-synchronizing literals
      imap.test_args "sync-literal-utf8", ["αβγδε"]
      assert_equal("sync-literal-utf8 ({10+}\r\nαβγδε)".b,
                   server.commands.pop.args)

      imap.test_args "utf8-with-wrong-encoding", "αβγδε".b
      assert_equal("utf8-with-wrong-encoding {10+}\r\nαβγδε".b,
                   server.commands.pop.args)

      imap.test_args "invalid-utf8", "\x80".b.force_encoding("UTF-8")
      assert_equal("invalid-utf8 {1+}\r\n\x80".b,
                   server.commands.pop.args)

      # Before enabling UTF-8 strings, without non-synchronizing literals
      imap.config.max_non_synchronizing_literal = -1
      imap.test_args "sync-literal-utf8", ["αβγδε"]
      assert_equal("sync-literal-utf8 ({10}\r\nαβγδε)".b,
                   server.commands.pop.args)

      imap.test_args "utf8-with-wrong-encoding", "αβγδε".b
      assert_equal("utf8-with-wrong-encoding {10}\r\nαβγδε".b,
                   server.commands.pop.args)

      imap.test_args "invalid-utf8", "\x80".b.force_encoding("UTF-8")
      assert_equal("invalid-utf8 {1}\r\n\x80".b,
                   server.commands.pop.args)

      # After enabling UTF-8 strings
      imap.enable(:utf8)
      assert imap.utf8_enabled?
      server.commands.pop.args => ["UTF8=ACCEPT"]

      imap.test_args "quoted-utf8", "αβγδε"
      assert_equal 'quoted-utf8 "αβγδε"'.b, server.commands.pop.args

      imap.test_args "utf8-with-wrong-encoding", "αβγδε".b
      assert_equal("utf8-with-wrong-encoding {10}\r\nαβγδε".b,
                   server.commands.pop.args)

      imap.test_args "invalid-utf8", "\x80".b.force_encoding("UTF-8")
      assert_equal("invalid-utf8 {1}\r\n\x80".b,
                   server.commands.pop.args)
    end
  end

  test("send literal args") do
    with_fake_server(with_extensions: %w[LITERAL-]) do |server, imap|
      # disable automatic non-synchronizing literals
      imap.config.max_non_synchronizing_literal = -1
      server.on "TEST", &:done_ok
      send_args = ->(*args) do
        imap.__send__(:send_command, "TEST", *args)
      end
      send_args.call ["\xDE\xAD\xBE\xEF".b]
      assert_equal "({4}\r\n\xDE\xAD\xBE\xEF)".b, server.commands.pop.args

      send_args.call ["hi\rthere\n", "huh?\r\nfake out"]
      assert_equal "({9}\r\nhi\rthere\n {14}\r\nhuh?\r\nfake out)".b,
                   server.commands.pop.args

      # enable automatic non-synchronizing literals
      imap.config.max_non_synchronizing_literal = 1024
      buff = bytes = nil
      server.literal_acceptor = proc { buff, bytes = _1, _2; false }
      server.on "TEST", &:done_ok
      send_args = ->(*args) do
        imap.__send__(:send_command, "TEST", *args)
      end
      send_args.call ["\xDE\xAD\xBE\xEF".b]
      assert_equal "({4+}\r\n\xDE\xAD\xBE\xEF)".b, server.commands.pop.args
      assert_nil buff
      assert_nil bytes

      # limited automatic non-synchronizing literals
      imap.config.max_non_synchronizing_literal = 5
      assert_local_raise(Net::IMAP::NoResponseError) do
        send_args.call [
          Net::IMAP::Literal["\rhi\r"],
          Net::IMAP::Literal["\x01" * 10],
        ]
      end
      assert_match(/TEST \(\{4\+\}\r\n\rhi\r \{10\}\r\n\z/, buff)
      assert_equal 10, bytes
      assert_empty server.commands

      server.literal_acceptor = proc { true }
      send_args.call Net::IMAP::Literal["\x01" * 10]
      assert_equal "{10}\r\n\x01\x01\x01\x01\x01\x01\x01\x01\x01\x01",
        server.commands.pop.args

      buff = bytes = nil
      server.literal_acceptor = proc { buff, bytes = _1, _2; false }
      send_args.call("nonsync",
                     Net::IMAP::Literal[data: "\x01\x02\x03", non_sync: true])
      assert_equal "nonsync {3+}\r\n\x01\x02\03".b, server.commands.pop.args
      assert_nil buff
      assert_nil bytes

      imap.config.max_non_synchronizing_literal = 5
      server.literal_acceptor = proc { true }
      send_args.call("literal",   Net::IMAP::Literal["\r",       false],
                     "literal",   Net::IMAP::Literal["αβ",         nil],
                     "literal",   Net::IMAP::Literal["αβγδε",      nil],
                     "literal+",  Net::IMAP::Literal["αβγδε",     true],
                     "literal8",  Net::IMAP::Literal8["\0",      false],
                     "literal8+", Net::IMAP::Literal8["\0" * 2,    nil],
                     "literal8",  Net::IMAP::Literal8["\0" * 6,    nil],
                     "literal8+", Net::IMAP::Literal8["\0" * 8,   true],
                     "done")
      assert_equal("literal"   " {1}\r\n\r "                 \
                   "literal"   " {4+}\r\nαβ "                \
                   "literal"   " {10}\r\nαβγδε "             \
                   "literal+"  " {10+}\r\nαβγδε "            \
                   "literal8"  " ~{1}\r\n\0 "                \
                   "literal8+" " ~{2+}\r\n\0\0 "             \
                   "literal8"  " ~{6}\r\n\0\0\0\0\0\0 "      \
                   "literal8+" " ~{8+}\r\n\0\0\0\0\0\0\0\0 " \
                   "done".b,
                   server.commands.pop.args)
    end
  end

  test("send non-synchronizing literals with LITERAL+") do
    with_fake_server(
      with_extensions: %w[LITERAL+], greeting_capabilities: true,
    ) do |server, imap|
      def imap.send_test_args(*args) = send_command("TEST", *args)
      server.on "TEST", &:done_ok

      imap.config.max_non_synchronizing_literal = 5_000
      large = "\xff".b * 5_000
      imap.send_test_args Net::IMAP::Literal[large, nil]
      assert_equal("{5000+}\r\n#{large}".b, server.commands.pop.args)

      large = "\xff".b * 10_000
      imap.send_test_args Net::IMAP::Literal[large, nil]
      assert_equal("{10000}\r\n#{large}".b, server.commands.pop.args)

      imap.send_test_args Net::IMAP::Literal[large, true]
      assert_equal("{10000+}\r\n#{large}".b, server.commands.pop.args)
    end
  end

  test("send non-synchronizing literal that's too large for LITERAL-") do
    with_fake_server(
      with_extensions: %w[LITERAL-], greeting_capabilities: true,
      ignore_abrupt_eof: true, ignore_io_error: true
    ) do |server, imap|
      def imap.send_test_args(*args) = send_command("TEST", *args)
      server.on "TEST", &:done_ok
      assert_raise(Net::IMAP::DataFormatError) do
        imap.send_test_args Net::IMAP::Literal["\xff".b * 5000, true]
      end
      assert imap.disconnected?
    end
  end

  test("send non-synchronizing literal without known server support") do
    with_fake_server(
      with_extensions: %w[LITERAL+], greeting_capabilities: false,
      ignore_abrupt_eof: true, ignore_io_error: true
    ) do |server, imap|
      def imap.send_test_args(*args) = send_command("TEST", *args)
      server.on "TEST", &:done_ok
      assert_raise(Net::IMAP::DataFormatError) do
        imap.send_test_args Net::IMAP::Literal["\xff".b * 100, true]
      end
      assert imap.disconnected?
    end
  end

end
