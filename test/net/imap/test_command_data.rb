# frozen_string_literal: true

require "net/imap"
require "test/unit"

class CommandDataTest < Net::IMAP::TestCase
  DataFormatError = Net::IMAP::DataFormatError

  Literal = Net::IMAP::Literal
  Literal8 = Net::IMAP::Literal8

  Output = Data.define(:name, :args)
  TAG = Module.new.freeze

  class FakeCommandWriter
    def self.def_printer(name)
      unless Net::IMAP.instance_methods.include?(name) ||
          Net::IMAP.private_instance_methods.include?(name)
        raise NoMethodError, "#{name} is not a method on Net::IMAP"
      end
      define_method(name) do |*args|
        output << Output[name:, args:]
      end
      Output.define_singleton_method(name) do |*args|
        new(name:, args:)
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

  test "Literal" do
    imap = FakeCommandWriter.new
    imap.send_data Literal["foo\r\nbar"]
    assert_equal [
      Output.send_literal("foo\r\nbar", TAG),
    ], imap.output

    imap.clear
    assert_raise_with_message(Net::IMAP::DataFormatError, /\bNULL byte\b/i) do
      imap.send_data Literal["contains NULL char: \0"]
    end
    assert_empty imap.output
  end

  test "Literal8" do
    imap = FakeCommandWriter.new
    imap.send_data Literal8["foo\r\nbar"], Literal8["foo\0bar"]
    assert_equal [
      Output.send_binary_literal("foo\r\nbar", TAG),
      Output.send_binary_literal("foo\0bar", TAG),
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
