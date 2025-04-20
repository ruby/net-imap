# frozen_string_literal: true

require "net/imap"
require "stringio"
require "test/unit"

class ResponseReaderTest < Test::Unit::TestCase
  def setup
    Net::IMAP.config.reset
  end

  class FakeClient
    def config; @config ||= Net::IMAP.config.new end
  end

  def literal(str) "{#{str.bytesize}}\r\n#{str}" end

  test "#read_response_buffer" do
    client = FakeClient.new
    aaaaaaaaa    = "a" * (20 << 10)
    many_crs     = "\r" * 1000
    many_crlfs   = "\r\n" * 500
    simple       = "* OK greeting\r\n"
    long_line    = "tag ok #{aaaaaaaaa} #{aaaaaaaaa}\r\n"
    literal_aaaa = "* fake #{literal aaaaaaaaa}\r\n"
    literal_crlf = "tag ok #{literal many_crlfs} #{literal many_crlfs}\r\n"
    zero_literal = "tag ok #{literal ""} #{literal ""}\r\n"
    illegal_crs  = "tag ok #{many_crs} #{many_crs}\r\n"
    illegal_lfs  = "tag ok #{literal "\r"}\n#{literal "\r"}\n\r\n"
    io = StringIO.new([
      simple,
      long_line,
      literal_aaaa,
      literal_crlf,
      zero_literal,
      illegal_crs,
      illegal_lfs,
      simple,
    ].join)
    rcvr = Net::IMAP::ResponseReader.new(client, io)
    assert_equal simple,       rcvr.read_response_buffer.to_str
    assert_equal long_line,    rcvr.read_response_buffer.to_str
    assert_equal literal_aaaa, rcvr.read_response_buffer.to_str
    assert_equal literal_crlf, rcvr.read_response_buffer.to_str
    assert_equal zero_literal, rcvr.read_response_buffer.to_str
    assert_equal illegal_crs,  rcvr.read_response_buffer.to_str
    assert_equal illegal_lfs,  rcvr.read_response_buffer.to_str
    assert_equal simple,       rcvr.read_response_buffer.to_str
    assert_equal "",           rcvr.read_response_buffer.to_str
  end

  class LimitedResponseReader < Net::IMAP::ResponseReader
    attr_reader :max_response_size
    def initialize(*args, max_response_size:)
      super(*args)
      @max_response_size = max_response_size
    end
  end

  test "#read_response_buffer with max_response_size" do
    client = FakeClient.new
    max_response_size = 10
    under = "+ 3456\r\n"
    exact = "+ 345678\r\n"
    over  = "+ 3456789\r\n"
    io = StringIO.new([under, exact, over].join)
    rcvr = LimitedResponseReader.new(client, io, max_response_size:)
    assert_equal under, rcvr.read_response_buffer.to_str
    assert_equal exact, rcvr.read_response_buffer.to_str
    assert_raise Net::IMAP::ResponseTooLargeError do
      rcvr.read_response_buffer
    end
  end

end
