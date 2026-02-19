# frozen_string_literal: true

require "net/imap"
require "test/unit"

class CommandDataTest < Test::Unit::TestCase
  DataFormatError = Net::IMAP::DataFormatError

  Literal = Net::IMAP::Literal
  Literal8 = Net::IMAP::Literal8

  # simplistic emulation of Output = Data.define(:name, :args)
  class Output
    class << self
      def new(_name = nil, _args = nil, name: _name, args: _args)
        raise ArgumentError, "missing name" unless name
        raise ArgumentError, "missing args" unless args
        super(name: name, args: args)
      end
      alias :[] :new
    end

    attr_reader :name, :args

    def initialize(name:, args:)
      @name, @args = name, args
      freeze
    end

    def to_h(&block) block ? to_h.to_h(&block) : { name: name, args: args } end
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
      define_method(name) do |*args|
        output << Output[name, args]
      end
      Output.define_singleton_method(name) do |*args|
        new(name, args)
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

end
