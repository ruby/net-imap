# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "net_imap_test_helpers"

class IMAPResponseParserTest < Test::Unit::TestCase
  TEST_FIXTURE_PATH = File.join(__dir__, "fixtures/response_parser")

  include NetIMAPTestHelpers
  extend  NetIMAPTestHelpers::TestFixtureGenerators

  def setup
    @do_not_reverse_lookup = Socket.do_not_reverse_lookup
    Socket.do_not_reverse_lookup = true
  end

  def teardown
    Socket.do_not_reverse_lookup = @do_not_reverse_lookup
  end

  ############################################################################
  # Tests that do no more than parse an example response and assert the result
  # data has the correct values have been moved to yml test fixtures.
  #
  # TODO: add instructions for how to quickly add or update yaml tests
  ############################################################################
  # Core IMAP, by RFC9051 section (w/obsolete in relative RFC3501 section):

  # §7.3.2: NAMESPACE response (also RFC2342)
  generate_tests_from fixture_file: "namespace_responses.yml"

  # RFC3501 §7.2.5: SEARCH response (obsolete in IMAP4rev2):
  generate_tests_from fixture_file: "search_responses.yml"

  # §7.5.2: FETCH response, BODYSTRUCTURE msg-att
  generate_tests_from fixture_file: "body_structure_responses.yml"

  ############################################################################
  # IMAP extensions, by RFC:

  ############################################################################
  # More interesting tests about the behavior, either of the test or of the
  # response data, should still use normal tests, below
  ############################################################################

  def test_flag_list_many_same_flags
    parser = Net::IMAP::ResponseParser.new
    assert_nothing_raised do
      100.times do
      parser.parse(<<EOF.gsub(/\n/, "\r\n"))
* LIST (\\Foo) "." "INBOX"
EOF
      end
    end
  end

  def test_flag_xlist_inbox
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse(<<EOF.gsub(/\n/, "\r\n"))
* XLIST (\\Inbox) "." "INBOX"
EOF
    assert_equal [:Inbox], response.data.attr
  end

  def test_resp_text_code
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse(<<EOF.gsub(/\n/, "\r\n"))
* OK [CLOSED] Previous mailbox closed.
EOF
    assert_equal "CLOSED", response.data.code.name
  end

  def test_msg_att_extra_space
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse(<<EOF.gsub(/\n/, "\r\n"))
* 1 FETCH (UID 92285)
EOF
    assert_equal 92285, response.data.attr["UID"]

    response = parser.parse(<<EOF.gsub(/\n/, "\r\n"))
* 1 FETCH (UID 92285 )
EOF
    assert_equal 92285, response.data.attr["UID"]
  end

  def test_msg_att_parse_error
    parser = Net::IMAP::ResponseParser.new
    e = assert_raise(Net::IMAP::ResponseParseError) {
      parser.parse(<<EOF.gsub(/\n/, "\r\n"))
* 123 FETCH (UNKNOWN 92285)
EOF
    }
    assert_match(/ for \{123\}/, e.message)
  end

  def test_msg_att_rfc822_text
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse(<<EOF.gsub(/\n/, "\r\n"))
* 123 FETCH (RFC822 {5}
foo
)
EOF
    assert_equal("foo\r\n", response.data.attr["RFC822"])
    response = parser.parse(<<EOF.gsub(/\n/, "\r\n"))
* 123 FETCH (RFC822[] {5}
foo
)
EOF
    assert_equal("foo\r\n", response.data.attr["RFC822"])
  end

  def assert_parseable(s)
    parser = Net::IMAP::ResponseParser.new
    parser.parse(s.gsub(/\n/, "\r\n"))
  end

  # [Bug #8281]
  def test_acl
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse(<<EOF.gsub(/\n/, "\r\n"))
* ACL "INBOX/share" "imshare2copy1366146467@xxxxxxxxxxxxxxxxxx.com" lrswickxteda
EOF
    assert_equal("ACL", response.name)
    assert_equal(1, response.data.length)
    assert_equal("INBOX/share", response.data[0].mailbox)
    assert_equal("imshare2copy1366146467@xxxxxxxxxxxxxxxxxx.com",
                 response.data[0].user)
    assert_equal("lrswickxteda", response.data[0].rights)
  end

  # [Bug #8415]
  def test_capability
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse("* CAPABILITY st11p00mm-iscream009 1Q49 XAPPLEPUSHSERVICE IMAP4 IMAP4rev1 SASL-IR AUTH=ATOKEN AUTH=PLAIN\r\n")
    assert_equal("CAPABILITY", response.name)
    assert_equal("AUTH=PLAIN", response.data.last)
    response = parser.parse("* CAPABILITY st11p00mm-iscream009 1Q49 XAPPLEPUSHSERVICE IMAP4 IMAP4rev1 SASL-IR AUTH=ATOKEN AUTH=PLAIN \r\n")
    assert_equal("CAPABILITY", response.name)
    assert_equal("AUTH=PLAIN", response.data.last)
    response = parser.parse("* OK [CAPABILITY IMAP4rev1 SASL-IR 1234 NIL THIS+THAT + AUTH=PLAIN ID] IMAP4rev1 Hello\r\n")
    assert_equal("OK", response.name)
    assert_equal("IMAP4rev1 Hello", response.data.text)
    code = response.data.code
    assert_equal("CAPABILITY", code.name)
    assert_equal(
      ["IMAP4REV1", "SASL-IR", "1234", "NIL", "THIS+THAT", "+", "AUTH=PLAIN", "ID"],
      code.data
    )
  end

  def test_enable
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse("* ENABLED SMTPUTF8\r\n")
    assert_equal("ENABLED", response.name)
    assert_equal(1, response.data.length)
    assert_equal("SMTPUTF8", response.data.first)
  end

  def test_id
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse("* ID NIL\r\n")
    assert_equal("ID", response.name)
    assert_equal(nil, response.data)
    response = parser.parse("* ID (\"name\" \"GImap\" \"vendor\" \"Google, Inc.\" \"support-url\" NIL)\r\n")
    assert_equal("ID", response.name)
    assert_equal("GImap", response.data["name"])
    assert_equal("Google, Inc.", response.data["vendor"])
    assert_equal(nil, response.data.fetch("support-url"))
  end

  # [Bug #13649]
  def test_status
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse("* STATUS INBOX (UIDNEXT 1 UIDVALIDITY 1234)\r\n")
    assert_equal("STATUS", response.name)
    assert_equal("INBOX", response.data.mailbox)
    assert_equal(1234, response.data.attr["UIDVALIDITY"])
    response = parser.parse("* STATUS INBOX (UIDNEXT 1 UIDVALIDITY 1234) \r\n")
    assert_equal("STATUS", response.name)
    assert_equal("INBOX", response.data.mailbox)
    assert_equal(1234, response.data.attr["UIDVALIDITY"])
  end

  # [Bug #10119]
  def test_msg_att_modseq_data
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse("* 1 FETCH (FLAGS (\Seen) MODSEQ (12345) UID 5)\r\n")
    assert_equal(12345, response.data.attr["MODSEQ"])
  end

  def test_msg_rfc3501_response_text_with_T_LBRA
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse("RUBY0004 OK [READ-WRITE] [Gmail]/Sent Mail selected. (Success)\r\n")
    assert_equal("RUBY0004", response.tag)
    assert_equal("READ-WRITE", response.data.code.name)
    assert_equal("[Gmail]/Sent Mail selected. (Success)", response.data.text)
  end

  def test_msg_rfc3501_response_text_with_BADCHARSET_astrings
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse("t BAD [BADCHARSET (US-ASCII \"[astring with brackets]\")] unsupported charset foo.\r\n")
    assert_equal("t", response.tag)
    assert_equal("unsupported charset foo.", response.data.text)
    assert_equal("BADCHARSET", response.data.code.name)
  end

  def test_continuation_request_without_response_text
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse("+\r\n")
    assert_instance_of(Net::IMAP::ContinuationRequest, response)
    assert_equal(nil, response.data.code)
    assert_equal("", response.data.text)
  end

  def test_ignored_response
    parser = Net::IMAP::ResponseParser.new
    response = nil
    assert_nothing_raised do
      response = parser.parse("* NOOP\r\n")
    end
    assert_instance_of(Net::IMAP::IgnoredResponse, response)
  end

  def test_uidplus_appenduid
    parser = Net::IMAP::ResponseParser.new
    # RFC4315 example
    response = parser.parse(
      "A003 OK [APPENDUID 38505 3955] APPEND completed\r\n"
    )
    code = response.data.code
    assert_equal   "APPENDUID", code.name
    assert_kind_of Net::IMAP::UIDPlusData, code.data
    assert_equal   Net::IMAP::UIDPlusData.new(38505, nil, [3955]), code.data
    assert_equal   "APPENDUID", code.name
    assert_kind_of Net::IMAP::UIDPlusData, code.data
    assert_equal   Net::IMAP::UIDPlusData.new(38505, nil, [3955]), code.data
    # MULTIAPPEND compatibility:
    response = parser.parse(
      "A003 OK [APPENDUID 2 4,6:7,9] APPEND completed\r\n"
    )
    code = response.data.code
    assert_equal   "APPENDUID", code.name
    assert_kind_of Net::IMAP::UIDPlusData, code.data
    assert_equal   Net::IMAP::UIDPlusData.new(2, nil, [4, 6, 7, 9]), code.data
  end

  def test_uidplus_copyuid
    parser = Net::IMAP::ResponseParser.new
    # RFC4315 example, but using mixed case "copyUID".
    response = parser.parse(
      "A004 OK [copyUID 38505 304,319:320 3956:3958] Done\r\n"
    )
    code = response.data.code
    assert_equal   "COPYUID", code.name
    assert_kind_of Net::IMAP::UIDPlusData, code.data
    assert_equal   Net::IMAP::UIDPlusData.new(
      38505, [304, 319, 320], [3956, 3957, 3958]
    ), code.data
  end

  # From RFC4315 ABNF:
  # > and all values between these two *regardless of order*.
  # > Example: 2:4 and 4:2 are equivalent.
  def test_uidplus_copyuid__reversed_ranges
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse(
      "A004 OK [copyUID 9999 20:19,500:495 92:97,101:100] Done\r\n"
    )
    code = response.data.code
    assert_equal Net::IMAP::UIDPlusData.new(
      9999,
      [19, 20, 495, 496, 497, 498, 499, 500],
      [92, 93, 94, 95, 96, 97, 100, 101]
    ), code.data
  end

  def test_uidplus_copyuid__uid_mapping
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse(
      "A004 OK [copyUID 9999 20:19,500:495 92:97,101:100] Done\r\n"
    )
    code = response.data.code
    assert_equal(
      {
         19 =>  92,
         20 =>  93,
        495 =>  94,
        496 =>  95,
        497 =>  96,
        498 =>  97,
        499 => 100,
        500 => 101,
      },
      code.data.uid_mapping
    )
  end

end
