# frozen_string_literal: true

require "net/imap"
require "test/unit"

module FetchDataSharedTests
  BodyTypeMessage = Net::IMAP::BodyTypeMessage
  Envelope = Net::IMAP::Envelope
  def self.included(mod)
    # "simple" attrs merely return exactly what is in the attr of the same name
    mod.test "simple RFC3501 and RFC9051 attrs accessors" do
      data = fetch_data_class.new(
        22222,
        {
          "FLAGS" => ["foo", :seen, :flagged],
          "BODY" => BodyTypeMessage.new(:body, :no_exts),
          "BODYSTRUCTURE" => BodyTypeMessage.new(:body, :with_exts),
          "ENVELOPE" => Envelope.new(:foo, :bar, :baz),
          "RFC822.SIZE" => 12_345,
        }
      )
      assert_equal ["foo", :seen, :flagged], data.flags
      assert_equal BodyTypeMessage.new(:body, :no_exts), data.body
      assert_equal BodyTypeMessage.new(:body, :with_exts), data.bodystructure
      assert_equal BodyTypeMessage.new(:body, :with_exts), data.body_structure
      assert_equal Envelope.new(:foo, :bar, :baz), data.envelope
      assert_equal 12_345, data.rfc822_size
      assert_equal 12_345, data.size
    end

    mod.test "#modseq returns MODSEQ value (RFC7162: CONDSTORE)" do
      data = fetch_data_class.new(22222, { "MODSEQ" => 123_456_789 })
      assert_equal(123_456_789, data.modseq)
    end

    mod.test "#emailid returns EMAILID value (RFC8474: OBJECTID)" do
      data = fetch_data_class.new(22222, { "EMAILID" => "THIS-IS-IT-01234" })
      assert_equal "THIS-IS-IT-01234", data.emailid
    end

    mod.test "#threadid returns THREADID value (RFC8474: OBJECTID)" do
      data = fetch_data_class.new(22222, { "THREADID" => "THAT-IS-THAT-98765" })
      assert_equal "THAT-IS-THAT-98765", data.threadid
    end

    mod.test "simple RFC822 attrs accessors (deprecated by RFC9051)" do
      data = fetch_data_class.new(
        22222, {
          "RFC822" => "RFC822 formatted message",
          "RFC822.TEXT" => "message text",
          "RFC822.HEADER" => "RFC822-headers: unparsed\r\n",
        }
      )
      assert_equal("RFC822 formatted message", data.rfc822)
      assert_equal("message text", data.rfc822_text)
      assert_equal("RFC822-headers: unparsed\r\n", data.rfc822_header)
    end

    mod.test "#internaldate parses a datetime value" do
      assert_nil fetch_data_class.new(123, { "UID" => 456 }).internaldate
      data = fetch_data_class.new(1, { "INTERNALDATE" => "17-Jul-1996 02:44:25 -0700" })
      time = Time.parse("1996-07-17T02:44:25-0700")
      assert_equal time, data.internaldate
      assert_equal time, data.internal_date
    end

    mod.test "#message returns the BODY[] attr" do
      data = fetch_data_class.new(1, { "BODY[]" => "RFC5322 formatted message" })
      assert_equal("RFC5322 formatted message", data.message)
    end

    mod.test "#message(offset:) returns the BODY[]<offset> attr" do
      data = fetch_data_class.new(1, { "BODY[]<12345>" => "partial message 1" })
      assert_equal "partial message 1", data.message(offset: 12_345)
    end

    mod.test "#part(1, 2, 3) returns the BODY[1.2.3] attr" do
      data = fetch_data_class.new(1, { "BODY[1.2.3]" => "Part" })
      assert_equal "Part", data.part(1, 2, 3)
    end

    mod.test "#part(1, 2, oFfset: 456) returns the BODY[1.2]<456> attr" do
      data = fetch_data_class.new(1, { "BODY[1.2]<456>" => "partial" })
      assert_equal "partial", data.part(1, 2, offset: 456)
    end

    mod.test "#text returns the BODY[TEXT] attr" do
      data = fetch_data_class.new(1, { "BODY[TEXT]" => "message text" })
      assert_equal "message text", data.text
    end

    mod.test "#text(1, 2, 3) returns the BODY[1.2.3.TEXT] attr" do
      data = fetch_data_class.new(1, { "BODY[1.2.3.TEXT]" => "part text" })
      assert_equal "part text", data.text(1, 2, 3)
    end

    mod.test "#text(1, 2, 3, oFfset: 456) returns the BODY[1.2.3.TEXT]<456> attr" do
      data = fetch_data_class.new(1, { "BODY[1.2.3.TEXT]<456>" => "partial text" })
      assert_equal "partial text", data.text(1, 2, 3, offset: 456)
    end

    mod.test "#header returns the BODY[HEADER] attr" do
      data = fetch_data_class.new(1, { "BODY[HEADER]" => "Message: header" })
      assert_equal "Message: header", data.header
    end

    mod.test "#header(1, 2, 3) returns the BODY[1.2.3.HEADER] attr" do
      data = fetch_data_class.new(1, { "BODY[1.2.3.HEADER]" => "Part: header" })
      assert_equal "Part: header", data.header(1, 2, 3)
    end

    mod.test "#header(1, 2, oFfset: 456) returns the BODY[1.2.HEADER]<456> attr" do
      data = fetch_data_class.new(1, { "BODY[1.2.HEADER]<456>" => "partial header" })
      assert_equal "partial header", data.header(1, 2, offset: 456)
    end

    mod.test "#header_fields(*) => BODY[HEADER.FIELDS (*)] attr" do
      data = fetch_data_class.new(1, { "BODY[HEADER.FIELDS (Foo Bar)]" => "foo bar" })
      assert_equal "foo bar", data.header_fields("foo", "BAR")
      assert_equal "foo bar", data.header(fields: %w[foo BAR])
    end

    mod.test "#header_fields(*, part:) => BODY[part.HEADER.FIELDS (*)] attr" do
      data = fetch_data_class.new(1, { "BODY[1.HEADER.FIELDS (Foo Bar)]" => "foo bar" })
      assert_equal "foo bar", data.header_fields("foo", "BAR", part: 1)
      assert_equal "foo bar", data.header(1, fields: %w[foo BAR])
      data = fetch_data_class.new(1, { "BODY[1.2.HEADER.FIELDS (Foo Bar)]" => "foo bar" })
      assert_equal "foo bar", data.header_fields("foo", "BAR", part: [1, 2])
      assert_equal "foo bar", data.header(1, 2, fields: %w[foo BAR])
    end

    mod.test "#header_fields(*, offset:) => BODY[part.HEADER.FIELDS (*)]<offset>" do
      data = fetch_data_class.new(1, { "BODY[1.HEADER.FIELDS (List-ID)]<1>" => "foo bar" })
      assert_equal "foo bar", data.header_fields("List-Id", part: 1, offset: 1)
      assert_equal "foo bar", data.header(1, fields: %w[List-Id], offset: 1)
    end

    mod.test "#header_fields_not(*) => BODY[HEADER.FIELDS.NOT (*)] attr" do
      data = fetch_data_class.new(1, { "BODY[HEADER.FIELDS.NOT (Foo Bar)]" => "foo bar" })
      assert_equal "foo bar", data.header_fields_not("foo", "BAR")
      assert_equal "foo bar", data.header(except: %w[foo BAR])
    end

    mod.test "#header_fields_not(*, part:) => BODY[part.HEADER.FIELDS.NOT (*)] attr" do
      data = fetch_data_class.new(1, { "BODY[1.HEADER.FIELDS.NOT (Foo Bar)]" => "foo bar" })
      assert_equal "foo bar", data.header_fields_not("foo", "BAR", part: 1)
      assert_equal "foo bar", data.header(1, except: %w[foo BAR])
      data = fetch_data_class.new(1, { "BODY[1.2.HEADER.FIELDS.NOT (Foo Bar)]" => "foo bar" })
      assert_equal "foo bar", data.header_fields_not("foo", "BAR", part: [1, 2])
      assert_equal "foo bar", data.header(1, 2, except: %w[foo BAR])
    end

    mod.test "#header_fields_not(*, offset:) => BODY[part.HEADER.FIELDS.NOT (*)]<offset>" do
      data = fetch_data_class.new(1, { "BODY[1.HEADER.FIELDS.NOT (List-ID)]<1>" => "foo bar" })
      assert_equal "foo bar", data.header_fields_not("List-Id", part: 1, offset: 1)
      assert_equal "foo bar", data.header(1, except: %w[List-Id], offset: 1)
    end

    mod.test "#mime(1, 2, 3) returns the BODY[1.2.3.MIME] attr" do
      data = fetch_data_class.new(1, { "BODY[1.2.3.MIME]" => "Part: mime" })
      assert_equal "Part: mime", data.mime(1, 2, 3)
    end

    mod.test "#mime(1, 2, oFfset: 456) returns the BODY[1.2.MIME]<456> attr" do
      data = fetch_data_class.new(1, { "BODY[1.2.MIME]<456>" => "partial mime" })
      assert_equal "partial mime", data.mime(1, 2, offset: 456)
    end

    mod.test "#binary(1, 2, 3, offset: 1) returns the BINARY[1.2.3]<1> attr" do
      data = fetch_data_class.new(1, {
        "BINARY[]" => "binary\0whole".b,
        "BINARY[1.2.3]" => "binary\0part".b,
        "BINARY[1.2.3]<1>" => "inary\0pa".b,
      })
      assert_equal "binary\0whole".b, data.binary
      assert_equal "binary\0part".b, data.binary(1, 2, 3)
      assert_equal "inary\0pa".b, data.binary(1, 2, 3, offset: 1)
    end

    mod.test "#binary_size(1, 2, 3) returns the BINARY.SIZE[1.2.3] attr" do
      data = fetch_data_class.new(1, {
        "BINARY.SIZE[]" => 987_654,
        "BINARY.SIZE[1.2.3]" => 123_456,
      })
      assert_equal 987_654, data.binary_size
      assert_equal 123_456, data.binary_size(1, 2, 3)
      assert_equal 123_456, data.binary_size([1, 2, 3])
    end
  end
end

class FetchDataTest < Test::Unit::TestCase
  FetchData = Net::IMAP::FetchData

  def fetch_data_class
    FetchData
  end

  test "#seqno" do
    data = FetchData.new(22222, "UID" => 54_321)
    assert_equal 22222, data.seqno
  end

  test "#uid" do
    data = FetchData.new(22222, "UID" => 54_321)
    assert_equal 54_321, data.uid
  end

  include FetchDataSharedTests
end
