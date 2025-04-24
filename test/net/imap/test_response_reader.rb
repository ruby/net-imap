# frozen_string_literal: true

require "net/imap"
require "stringio"
require "test/unit"

class ResponseReaderTest < Test::Unit::TestCase
  def setup
    Net::IMAP.config.reset
  end

  class FakeClient
    def config = @config ||= Net::IMAP.config.new
    def max_response_size = config.max_response_size
    def socket_read_limit = config.socket_read_limit
  end

  def literal(str) = "{#{str.bytesize}}\r\n#{str}"

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

  test "#read_response_buffer with max_response_size" do
    client = FakeClient.new
    client.config.max_response_size = 10
    under = "+ 3456\r\n"
    exact = "+ 345678\r\n"
    over  = "+ 3456789\r\n"
    io = StringIO.new([under, exact, over].join)
    rcvr = Net::IMAP::ResponseReader.new(client, io)
    assert_equal under, rcvr.read_response_buffer.to_str
    assert_equal exact, rcvr.read_response_buffer.to_str
    assert_raise Net::IMAP::ResponseTooLargeError do
      rcvr.read_response_buffer
    end
  end

  test "#read_response_buffer with socket_read_limit" do
    client = FakeClient.new
    client.config.socket_read_limit = 10
    aaaaaaaaa    = "a" * (20 << 10)
    many_crs     = "\r" * 1000
    many_crlfs   = "\r\n" * 100
    mega_response = [
      "* fake",
      aaaaaaaaa,
      literal(aaaaaaaaa),
      literal(many_crlfs),
      literal(literal(literal(many_crlfs))),
      literal(many_crs),
      many_crs,
    ].join(" ")
    io = StringIO.new(mega_response)
    rcvr = Net::IMAP::ResponseReader.new(client, io)
    assert_equal mega_response, rcvr.read_response_buffer.to_str
    assert_equal "",           rcvr.read_response_buffer.to_str
  end

end
