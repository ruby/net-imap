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

end
