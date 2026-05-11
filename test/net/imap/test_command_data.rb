# frozen_string_literal: true

require "net/imap"
require "test/unit"

class CommandDataTest < Test::Unit::TestCase
  DataFormatError = Net::IMAP::DataFormatError

  Atom = Net::IMAP::Atom
  Flag = Net::IMAP::Flag
  QuotedString = Net::IMAP::QuotedString
  Literal = Net::IMAP::Literal
  Literal8 = Net::IMAP::Literal8
  RawText = Net::IMAP::RawText
  RawData = Net::IMAP::RawData

  # simplistic emulation of Output = Data.define(:name, :args)
  class Output
    class << self
      def new(_name = nil, _args = nil, _kw = nil, name: _name, args: _args, kwargs: _kw)
        raise ArgumentError, "missing name" unless name
        raise ArgumentError, "missing args" unless args
        super(name: name, args: args, kwargs: kwargs)
      end
      alias :[] :new
    end

    attr_reader :name, :args, :kwargs

    def initialize(name:, args:, kwargs:)
      @name, @args, @kwargs = name, args, kwargs
      freeze
    end

    def to_h(&block)
      block ? to_h.to_h(&block) : { name: name, args: args, kwargs: kwargs }
    end
    def ==(other)   Output === other && to_h  ==  other.to_h  end
    def eql?(other) Output === other && to_h.eql?(other.to_h) end
  end

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
        output << Output[name: name, args: args, kwargs: kwargs]
      end
      Output.define_singleton_method(name) do |*args, **kwargs|
        kwargs = kwargs.compact
        kwargs = nil if kwargs.empty?
        new(name: name, args: args, kwargs: kwargs)
      end
    end

    attr_reader :output

    def initialize
      @output = []
    end

    def clear; @output.clear end
    def validate(*data); data.each(&:validate) end
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
      "", # empty
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
      :"", # empty
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

  class QuotedStringTest < CommandDataTest
    test "quotes ASCII strings (no specials)" do
      assert_equal '"INBOX"', QuotedString["INBOX"].formatted
      imap.send_data(
        QuotedString["INBOX"],
        QuotedString["etc"]
      )
      assert_equal [
        Output.put_string('"INBOX"'),
        Output.put_string('"etc"'),
      ], imap.output
      imap.clear
    end

    test "quotes ASCII strings (atom specials)" do
      [
        "  with  spaces  in  string  ",
        "with_parens()",
        "with_list_wildcards*",
        "with_list_wildcards%",
        "with_resp_special]",
        "with\x7fcontrol_char",
        %{(){}[]%*'},
      ].each do |string|
        imap.send_data QuotedString[string]
      end
      assert_equal [
        Output.put_string('"  with  spaces  in  string  "'),
        Output.put_string('"with_parens()"'),
        Output.put_string('"with_list_wildcards*"'),
        Output.put_string('"with_list_wildcards%"'),
        Output.put_string('"with_resp_special]"'),
        Output.put_string(%{"with\x7fcontrol_char"}),
        Output.put_string(%Q{"(){}[]%*'"}),
      ], imap.output
    end

    test "escapes quoted specials" do
      [
        '"with" "quoted" "specials"',
        "\\with\\quoted\\specials\\",
        %{(){}[]%*"'\\},
      ].each do |string|
        imap.send_data QuotedString[string]
      end
      assert_equal [
        Output.put_string('"\"with\" \"quoted\" \"specials\""'),
        Output.put_string('"\\\\with\\\\quoted\\\\specials\\\\"'),
        Output.put_string(%q{"(){}[]%*\"'\\\\"}),
      ], imap.output
    end

    test "ASCII compatible string with another encodings" do
      imap.send_data QuotedString.new("foo bar".encode("cp1252"))
      assert_equal [
        Output.put_string('"foo bar"'),
      ], imap.output
    end

    test "allows ASCII control chars" do
      text = QuotedString.new("beep\b beep\b escape!\e delete this:\x1f")
      imap.send_data text
      assert_equal [
        Output.put_string(%{"beep\b beep\b escape!\e delete this:\x1f"}),
      ], imap.output
    end

    test "quotes valid UTF-8 multibyte chars" do
      imap.send_data QuotedString.new("föó bär")
      imap.send_data QuotedString.new("ほげ ふが ぴよ")
      assert_equal [
        Output.put_string('"föó bär"'),
        Output.put_string('"ほげ ふが ぴよ"'),
      ], imap.output
    end
  end

  class RawTextTest < CommandDataTest
    test "allows ASCII strings with no specials" do
      imap.send_data(
        RawText["INBOX"],
        RawText["etc"]
      )
      assert_equal [
        Output.put_string("INBOX"),
        Output.put_string("etc"),
      ], imap.output
      imap.clear
    end

    test "allows atom specials" do
      [
        "  with  spaces  in  string  ",
        "with_parens()",
        "with_list_wildcards*",
        "with_list_wildcards%",
        "with_resp_special]",
        "with\x7fcontrol_char",
        %{(){}[]%*'},
      ].each do |string|
        imap.send_data RawText[string]
      end
      assert_equal [
        Output.put_string("  with  spaces  in  string  "),
        Output.put_string("with_parens()"),
        Output.put_string("with_list_wildcards*"),
        Output.put_string("with_list_wildcards%"),
        Output.put_string("with_resp_special]"),
        Output.put_string("with\x7fcontrol_char"),
        Output.put_string(%{(){}[]%*'}),
      ], imap.output
    end

    test "allows quoted specials" do
      [
        '"with" "quoted" "specials"',
        '\\with\\quoted\\specials\\',
        %{(){}[]%*"'\\},
      ].each do |string|
        imap.send_data RawText[string]
      end
      assert_equal [
        Output.put_string('"with" "quoted" "specials"'),
        Output.put_string('\\with\\quoted\\specials\\'),
        Output.put_string(%{(){}[]%*"'\\}),
      ], imap.output
    end

    test "ASCII compatible string with another encodings" do
      imap.send_data RawText.new("foo bar".encode("cp1252"))
      assert_equal [
        Output.put_string("foo bar"),
      ], imap.output
    end

    test "allows ASCII control chars" do
      text = RawText.new("beep\b beep\b escape!\e delete this:\x1f")
      imap.send_data text
      assert_equal [
        Output.put_string("beep\b beep\b escape!\e delete this:\x1f"),
      ], imap.output
    end

    test "allows valid UTF-8 multibyte chars" do
      imap.send_data RawText.new("föó bär")
      imap.send_data RawText.new("ほげ ふが ぴよ")
      assert_equal [
        Output.put_string("föó bär"),
        Output.put_string("ほげ ふが ぴよ"),
      ], imap.output
    end
  end

  SharedValidNonLiteralDataTests = ->(data_type) do
    data(
      "NULL" => ["with \0 NULL", /NULL\b.+\bbyte/i],
      "CR"   => ["with \r CR",   /CR\b.+\bbyte/i],
      "LF"   => ["with \n LF",   /LF\b.+\bbyte/i],
    )
    test "invalid ASCII byte" do |(text, error_message)|
      with_multiple_encodings(text) do |encoded|
        assert_raise_with_message(DataFormatError, error_message) do
          data_type[encoded]
        end
      end
    end

    # See Table 3-7, Well-Formed UTF-8 Byte Sequences, in The Unicode Standard:
    # https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-3/#G27506
    data(
      "incomplete 2 byte sequence" => "\xc3".b,
      "invalid 2 byte sequence"    => "\xc3\x7f".b,
      "incomplete 3 byte sequence" => "\xe0\x80\x80".b,
      "invalid 3 byte sequence"    => "\xe0\x80\x80".b,
      "incomplete 4 byte sequence" => "\xf1\x80\x80".b,
      "invalid 4 byte sequence"    => "\xf0\x80\x80\x80".b,
      "first byte too high"        => "\xff\xaa\xaa\xaa".b,
      "UTF-16 surrogate pair"      => "\xFE\xFF\xD8\x3D\xDC\xA3\xFE\x0F".b,
      "windows-1252"               => "åêïõü".encode("windows-1252"),
    )
    test "invalid UTF-8" do |text|
      with_multiple_encodings(text) do |encoded|
        assert_raise_with_message(DataFormatError, /invalid UTF-8/i) do
          data_type[encoded]
        end
      end
    end

    def with_multiple_encodings(data)
      yield data.b # BINARY
      yield data.dup.force_encoding("ASCII")
      yield data.dup.force_encoding("UTF-8")
      yield data.dup.force_encoding("cp1252")
    end
  end
  QuotedStringTest.class_exec QuotedString, &SharedValidNonLiteralDataTests
  RawTextTest     .class_exec RawText,      &SharedValidNonLiteralDataTests

  class RawDataTest < CommandDataTest
    test "simple raw text" do
      raw = RawData.new('foo "bar" baz')
      assert_equal [RawText['foo "bar" baz']], raw.data
      imap.send_data raw
      assert_equal [Output.put_string('foo "bar" baz')], imap.output
    end

    test "a single literal" do
      raw = RawData.new("{7}\r\nfoo bar")
      assert_equal [Literal["foo bar", false]], raw.data
      imap.send_data raw, tag: "t1"
      assert_equal [
        Output.send_literal("foo bar", "t1", non_sync: false),
      ], imap.output
    end

    test "literals embedded between text" do
      raw = RawData.new("foo bar {3}\r\nbaz {4+}\r\nquux etc")
      assert_equal [
        RawText["foo bar "],
        Literal["baz", false],
        RawText[" "],
        Literal["quux", true], # non-synchronizing
        RawText[" etc"],
      ], raw.data
      imap.send_data raw, tag: "t2"
      assert_equal [
        Output.put_string("foo bar "),
        Output.send_literal("baz", "t2", non_sync: false),
        Output.put_string(" "),
        Output.send_literal("quux", "t2", non_sync: true),
        Output.put_string(" etc"),
      ], imap.output
    end

    test "empty literals" do
      raw = RawData.new("{0}\r\n{0+}\r\n~{0}\r\n~{0+}\r\n")
      assert_equal [
        Literal["", false],
        Literal["", true],
        Literal8["", false],
        Literal8["", true],
      ], raw.data
      imap.send_data raw, tag: "t2.2"
      assert_equal [
        Output.send_literal("", "t2.2", non_sync: false),
        Output.send_literal("", "t2.2", non_sync: true),
        Output.send_binary_literal("", "t2.2", non_sync: false),
        Output.send_binary_literal("", "t2.2", non_sync: true),
      ], imap.output
    end

    test "raw text embedded between literals" do
      raw = RawData.new("{3}\r\nfoo bar")
      assert_equal [
        Literal["foo", false],
        RawText[" bar"]
      ], raw.data
      imap.send_data raw, tag: "t3"
      assert_equal [
        Output.send_literal("foo", "t3", non_sync: false),
        Output.put_string(" bar"),
      ], imap.output
    end

    test "raw text followed by literal" do
      raw = RawData.new("foo {3}\r\nbar")
      assert_equal [
        RawText["foo "],
        Literal["bar", false],
      ], raw.data
      imap.send_data raw, tag: "t4"
      assert_equal [
        Output.put_string("foo "),
        Output.send_literal("bar", "t4", non_sync: false),
      ], imap.output
      imap.clear
    end

    test "binary literal with regular literal" do
      raw = RawData.new("foo ~{7}\r\n\0bar\r\nbaz {4}\r\nquux")
      assert_equal [
        RawText["foo "],
        Literal8["\0bar\r\nb", false],
        RawText["az "],
        Literal["quux", false],
      ], raw.data
      imap.send_data raw, tag: "t5"
      assert_equal [
        Output.put_string("foo "),
        Output.send_binary_literal("\0bar\r\nb", "t5", non_sync: false),
        Output.put_string("az "),
        Output.send_literal("quux", "t5", non_sync: false),
      ], imap.output
    end

    data(
      "CR"   => "with \r byte",
      "LF"   => "with \n byte",
      "NULL" => "with \0 byte",
      "CRLF" => "with \r\n bytes",
    )
    test "invalid bytes in raw text" do |data|
      assert_raise_with_message(DataFormatError, /must be.* literal encoded/i) do
        RawData.new(data: data)
      end
    end

    test "invalid literal" do |data|
      assert_raise_with_message(DataFormatError, /too few bytes/i) do
        RawData.new(data: "invalid literal {123}\r\ntoo small")
      end

      assert_raise_with_message(DataFormatError, /NULL byte.*in.*literal/i) do
        RawData.new(data: "invalid literal {10}\r\ncontains \0 null")
      end
    end

    test "invalid literal ending ('{123}')" do
      assert_raise(DataFormatError) do RawData.new(data: "literal {123}") end
      assert_raise(DataFormatError) do RawData.new(data: "literal+ {123+}") end
      assert_raise(DataFormatError) do RawData.new(data: "~literal ~{123}") end
      assert_raise(DataFormatError) do RawData.new(data: "~literal+ ~{123+}") end
      raw = RawData.new(data: " {123} ")
      assert_equal [RawText[" {123} "]], raw.data

      assert_raise(DataFormatError) do RawData.new(data: "literal {0}") end
      assert_raise(DataFormatError) do RawData.new(data: "literal+ {0+}") end
      assert_raise(DataFormatError) do RawData.new(data: "~literal ~{0}") end
      assert_raise(DataFormatError) do RawData.new(data: "~literal+ ~{0+}") end
      raw = RawData.new(data: " {0} ")
      assert_equal [RawText[" {0} "]], raw.data
    end

    data(
      "simple raw text"     => 'hello "world"',
      "text, literal, text" => "OK {5}\r\nhello {5}\r\nworld",
      "empty literals"      => "{0}\r\n{0+}\r\n~{0}\r\n~{0+}\r\n",
      "binary and regular"  => "foo ~{7}\r\n\0bar\r\nbaz {4}\r\nquux",
    )
    test ".split" do |string|
      assert_equal(RawData[string].data, RawData.split(string))
    end

    test ".split allows final literal prefix" do
      assert_equal [RawText["text {123}"]],     RawData.split("text {123}")
      assert_equal [RawText["text+ {123+}"]],   RawData.split("text+ {123+}")
      assert_equal [RawText["~text ~{123}"]],   RawData.split("~text ~{123}")
      assert_equal [RawText["~text+ ~{123+}"]], RawData.split("~text+ ~{123+}")
    end
  end

end
