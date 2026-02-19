# frozen_string_literal: true

require "net/imap"
require "test/unit"

class CommandDataTest < Net::IMAP::TestCase
  DataFormatError = Net::IMAP::DataFormatError

  Atom = Net::IMAP::Atom
  Flag = Net::IMAP::Flag
  Literal = Net::IMAP::Literal
  Literal8 = Net::IMAP::Literal8

  Output = Data.define(:name, :args, :kwargs)
  TAG = Module.new.freeze

  class FakeCommandWriter
    def self.def_printer(name)
      unless Net::IMAP.instance_methods.include?(name) ||
          Net::IMAP.private_instance_methods.include?(name)
        raise NoMethodError, "#{name} is not a method on Net::IMAP"
      end
      define_method(name) do |*args, **kwargs|
        kwargs = kwargs.compact
        kwargs = nil if kwargs.empty?
        output << Output[name:, args:, kwargs:]
      end
      Output.define_singleton_method(name) do |*args, **kwargs|
        kwargs = kwargs.compact
        kwargs = nil if kwargs.empty?
        new(name:, args:, kwargs:)
      end
    end

    attr_reader :output

    def initialize
      @output = []
    end

    def clear = @output.clear
    def validate(*data) = data.each(&:validate)
    def send_data(*data, tag: TAG)
      validate(*data)
      data.each do _1.send_data(self, tag) end
    end

    def_printer :put_string
    def_printer :send_string_data
    def_printer :send_number_data
    def_printer :send_list_data
    def_printer :send_time_data
    def_printer :send_date_data
    def_printer :send_quoted_string
    def_printer :send_literal
    def_printer :send_binary_literal
  end

  attr_reader :imap

  setup do
    @imap = FakeCommandWriter.new
  end

  test "Atom" do
    imap.send_data(Atom[:INBOX], Atom["INBOX"], Atom["etc"])
    assert_equal [
      Output.put_string("INBOX"),
      Output.put_string("INBOX"),
      Output.put_string("etc"),
    ], imap.output

    imap.clear
    # atom may not contain atom-specials
    [
      "with_parens()",
      "with_list_wildcards*",
      "with_list_wildcards%",
      "with_resp_special]",
      "with\0null",
      "with\x7fcontrol_char",
      '"with_quoted_specials"',
      "with_quoted_specials\\",
      "with\rCR",
      "with\nLF",
    ].each do |symbol|
      assert_raise_with_message(Net::IMAP::DataFormatError, /\batom\b/i) do
        imap.send_data Atom[symbol]
      end
    end
    assert_empty imap.output
  end

  test "Flag" do
    imap.send_data(Flag[:Seen], Flag[:Flagged],
                   Flag["Deleted"], Flag["Answered"])
    assert_equal [
      Output.put_string("\\Seen"),
      Output.put_string("\\Flagged"),
      Output.put_string("\\Deleted"),
      Output.put_string("\\Answered"),
    ], imap.output

    imap.clear
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
        imap.send_data Flag[symbol]
      end
    end
    assert_empty imap.output
  end

  test "Literal" do
    imap.send_data Literal["foo\r\nbar"]
    imap.send_data Literal["foo\r\nbar", false]
    imap.send_data Literal["foo\r\nbar", true]
    assert_equal [
      Output.send_literal("foo\r\nbar", TAG),
      Output.send_literal("foo\r\nbar", TAG, non_sync: false),
      Output.send_literal("foo\r\nbar", TAG, non_sync: true),
    ], imap.output

    imap.clear
    assert_raise_with_message(Net::IMAP::DataFormatError, /\bNULL byte\b/i) do
      imap.send_data Literal["contains NULL char: \0"]
    end
    assert_empty imap.output
  end

  test "Literal8" do
    imap.send_data Literal8["foo\r\nbar"], Literal8["foo\0bar"]
    imap.send_data Literal8["foo\0bar", false]
    imap.send_data Literal8["foo\0bar", true]
    assert_equal [
      Output.send_binary_literal("foo\r\nbar", TAG),
      Output.send_binary_literal("foo\0bar", TAG),
      Output.send_binary_literal("foo\0bar", TAG, non_sync: false),
      Output.send_binary_literal("foo\0bar", TAG, non_sync: true),
    ], imap.output
  end

  class StringFormatterTest < Net::IMAP::TestCase
    include Net::IMAP::StringFormatter

    test "literal_or_literal8" do
      assert_kind_of Literal,  literal_or_literal8("simple\r\n")
      assert_kind_of Literal8, literal_or_literal8("has NULL \0")
      assert_kind_of Literal,  literal_or_literal8(Literal["foo"])
      assert_kind_of Literal8, literal_or_literal8(Literal8["foo"])
    end
  end

end
