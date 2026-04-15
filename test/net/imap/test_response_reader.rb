# frozen_string_literal: true

require "net/imap"
require "stringio"
require "test/unit"

class ResponseReaderTest < Net::IMAP::TestCase

  class FakeClient
    def config = @config ||= Net::IMAP.config.new
    def max_response_size = config.max_response_size
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
    zero_padded  = "+ {010}\r\n1234567890\r\n" # NOTE: it's decimal, not octal!
    goofy_zero   = "+ {000}\r\n\r\n"
    io = StringIO.new([
      simple,
      long_line,
      literal_aaaa,
      literal_crlf,
      zero_literal,
      illegal_crs,
      illegal_lfs,
      zero_padded,
      goofy_zero,
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
    assert_equal zero_padded,  rcvr.read_response_buffer.to_str
    assert_equal goofy_zero,   rcvr.read_response_buffer.to_str
    assert_equal simple,       rcvr.read_response_buffer.to_str
    assert_equal "",           rcvr.read_response_buffer.to_str
  end

  test "#read_response_buffer with max_response_size" do
    client = FakeClient.new
    client.config.max_response_size = 10
    under = "+ 3456\r\n"
    exact = "+ 345678\r\n"
    very_over     = "+ 3456789 #{?a * (16<<10)}}\r\n"
    slightly_over = "+ 34567890\r\n" # CRLF after the limit
    io = StringIO.new([under, exact, very_over, slightly_over].join, "rb")
    rcvr = Net::IMAP::ResponseReader.new(client, io)
    assert_equal under, rcvr.read_response_buffer.to_str
    assert_equal exact, rcvr.read_response_buffer.to_str
    assert_raise Net::IMAP::ResponseTooLargeError do
      result = rcvr.read_response_buffer
      flunk "Got result: %p" % [result]
    end
    io = StringIO.new(slightly_over, "rb")
    rcvr = Net::IMAP::ResponseReader.new(client, io)
    assert_raise Net::IMAP::ResponseTooLargeError do
      result = rcvr.read_response_buffer
      flunk "Got result: %p" % [result]
    end
  end

  test "#read_response_buffer max_response_size straddling CRLF" do
    barely_over = "+ 3456789\r\n"  # CRLF straddles the boundary
    client = FakeClient.new
    client.config.max_response_size = 10
    io = StringIO.new(barely_over, "rb")
    rcvr = Net::IMAP::ResponseReader.new(client, io)
    assert_raise Net::IMAP::ResponseTooLargeError do
      result = rcvr.read_response_buffer
      flunk "Got result: %p" % [result]
    end
  end

  data(
    bad_int64: "+ {99999999999999999999}\r\ndon't even try to read this...",
  )
  test "#read_response_buffer with invalid literal size" do |invalid|
    client  = FakeClient.new
    client.config.max_response_size = nil # any size is allowed!
    io = StringIO.new(invalid, "rb")
    rcvr = Net::IMAP::ResponseReader.new(client, io)
    assert_raise Net::IMAP::DataFormatError do
      result = rcvr.read_response_buffer
      flunk "Got result: %p" % [result]
    end
    # assert io.closed?
  end

  test "linear performance detecting literal continuation" do
    omit_unless_cruby "flaky on different platforms"
    omit_if(ENV["CI"], "slow and flaky, skipping in CI")

    client = FakeClient.new
    io = StringIO.new "", "rb"
    rcvr = Net::IMAP::ResponseReader.new(client, io)

    sequence = [100, 1_000, 10_000]
    assert_strict_linear_time(sequence, prepare: ->(n) {
      parts = Array.new(n) {|i| "BODY[#{i.succ}] {1}\r\nX" }.join(" ")
      response = "* 1 FETCH (#{parts})\r\n"
      embedded = "#{response}* OK next response\r\n"
      io.string = embedded
      assert_equal response, rcvr.read_response_buffer
      io.rewind
      response
    }) do
      io.rewind
      rcvr.read_response_buffer
    end
  end
end
