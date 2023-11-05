# frozen_string_literal: true

require "net/imap"
require "test/unit"

class IMAPDataEncodingTest < Test::Unit::TestCase

  def test_encode_utf7
    assert_equal("foo", Net::IMAP.encode_utf7("foo"))
    assert_equal("&-", Net::IMAP.encode_utf7("&"))

    utf8 = "\357\274\241\357\274\242\357\274\243".dup.force_encoding("UTF-8")
    s = Net::IMAP.encode_utf7(utf8)
    assert_equal("&,yH,Iv8j-", s)
    s = Net::IMAP.encode_utf7("foo&#{utf8}-bar".encode("EUC-JP"))
    assert_equal("foo&-&,yH,Iv8j--bar", s)

    utf8 = "\343\201\202&".dup.force_encoding("UTF-8")
    s = Net::IMAP.encode_utf7(utf8)
    assert_equal("&MEI-&-", s)
    s = Net::IMAP.encode_utf7(utf8.encode("EUC-JP"))
    assert_equal("&MEI-&-", s)
  end

  def test_decode_utf7
    assert_equal("&", Net::IMAP.decode_utf7("&-"))
    assert_equal("&-", Net::IMAP.decode_utf7("&--"))

    s = Net::IMAP.decode_utf7("&,yH,Iv8j-")
    utf8 = "\357\274\241\357\274\242\357\274\243".dup.force_encoding("UTF-8")
    assert_equal(utf8, s)

    assert_linear_performance([1, 10, 100], pre: ->(n) {'&'*(n*1_000)}) do |s|
      Net::IMAP.decode_utf7(s)
    end
  end

  def test_encode_date
    assert_equal("24-Jul-2009", Net::IMAP.encode_date(Time.mktime(2009, 7, 24)))
    assert_equal("24-Jul-2009", Net::IMAP.format_date(Time.mktime(2009, 7, 24)))
    assert_equal("06-Oct-2022", Net::IMAP.encode_date(Date.new(2022, 10, 6)))
  end

  def test_decode_date
    assert_equal Date.new(2022, 10, 6), Net::IMAP.decode_date("06-Oct-2022")
    assert_equal Date.new(2022, 10, 6), Net::IMAP.decode_date('"06-Oct-2022"')
    assert_equal Date.new(2022, 10, 6), Net::IMAP.parse_date("06-Oct-2022")
  end

  def test_encode_datetime
    time = Time.new(2009, 7, 24, 1, 3, 5, "+05:00")
    assert_equal('"24-Jul-2009 01:03:05 +0500"', Net::IMAP.encode_datetime(time))
    # assert_equal('"24-Jul-2009 01:03:05 +0500"', Net::IMAP.format_datetime(time))
    assert_equal('"24-Jul-2009 01:03:05 +0500"', Net::IMAP.format_time(time))
    assert_equal('"24-Jul-2009 01:03:05 +0500"', Net::IMAP.encode_time(time))
  end

  def test_decode_datetime
    expected = DateTime.new(2022, 10, 6, 1, 2, 3, "-04:00")
    actual   = Net::IMAP.decode_datetime('"06-Oct-2022 01:02:03 -0400"')
    assert_equal expected, actual
    actual   = Net::IMAP.decode_datetime("06-Oct-2022 01:02:03 -0400")
    assert_equal expected, actual
    actual   = Net::IMAP.parse_datetime '" 6-Oct-2022 01:02:03 -0400"'
    assert_equal expected, actual
  end

  def test_decode_time
    expected = DateTime.new(2020, 11, 7, 1, 2, 3, "-04:00").to_time
    actual   = Net::IMAP.parse_time '"07-Nov-2020 01:02:03 -0400"'
    assert_equal expected, actual
    actual   = Net::IMAP.decode_time '" 7-Nov-2020 01:02:03 -0400"'
    assert_equal expected, actual
    actual   = Net::IMAP.parse_time "07-Nov-2020 01:02:03 -0400"
    assert_equal expected, actual
  end

end
