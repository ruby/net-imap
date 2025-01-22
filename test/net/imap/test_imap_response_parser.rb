# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "net_imap_test_helpers"

class IMAPResponseParserTest < Test::Unit::TestCase
  TEST_FIXTURE_PATH = File.join(__dir__, "fixtures/response_parser")

  include NetIMAPTestHelpers
  extend  NetIMAPTestHelpers::TestFixtureGenerators

  def setup
    Net::IMAP.config.reset
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
  # The simplest way to add or update new test cases is to add only the test
  # name and response string to the yaml file, and then re-run the tests.  The
  # test will be marked pending, and the parsed result will be serialized and
  # printed on stdout.  This can then be copied into the yaml file.
  ############################################################################
  # Core IMAP, by RFC9051 section (w/obsolete in relative RFC3501 section):
  generate_tests_from fixture_file: "rfc3501_examples.yml"

  # §4.3: Strings (also §5.1, §9, and RFC6855):
  generate_tests_from fixture_file: "utf8_responses.yml"

  # §7.1: Generic Status Responses (OK, NO, BAD, PREAUTH, BYE, codes, text)
  generate_tests_from fixture_file: "resp_code_examples.yml"
  generate_tests_from fixture_file: "resp_cond_examples.yml"
  generate_tests_from fixture_file: "resp_text_responses.yml"

  # §7.2.1: ENABLED response
  generate_tests_from fixture_file: "enabled_responses.yml"

  # §7.2.2: CAPABILITY response
  generate_tests_from fixture_file: "capability_responses.yml"

  # §7.3.1: LIST response (including obsolete LSUB and XLIST responses)
  generate_tests_from fixture_file: "list_responses.yml"

  # §7.3.2: NAMESPACE response (also RFC2342)
  generate_tests_from fixture_file: "namespace_responses.yml"

  # §7.3.3: STATUS response
  generate_tests_from fixture_file: "status_responses.yml"

  # RFC3501 §7.2.5: SEARCH response (obsolete in IMAP4rev2):
  generate_tests_from fixture_file: "search_responses.yml"

  # §7.3.5: FLAGS response
  generate_tests_from fixture_file: "flags_responses.yml"

  # §7.4: Mailbox size, EXISTS and RECENT
  generate_tests_from fixture_file: "mailbox_size_responses.yml"

  # §7.5.1: EXPUNGE response
  generate_tests_from fixture_file: "expunge_responses.yml"

  # §7.5.2: FETCH response, misc msg-att
  generate_tests_from fixture_file: "fetch_responses.yml"

  # §7.5.2: FETCH response, BODYSTRUCTURE msg-att
  generate_tests_from fixture_file: "body_structure_responses.yml"

  # §7.6: Command Continuation Request
  generate_tests_from fixture_file: "continuation_requests.yml"

  ############################################################################
  # IMAP extensions, by RFC:

  # RFC 2971: ID response
  generate_tests_from fixture_file: "id_responses.yml"

  # RFC 4314: ACL response (TODO: LISTRIGHTS and MYRIGHTS responses)
  generate_tests_from fixture_file: "acl_responses.yml"

  # RFC 4315: UIDPLUS extension, APPENDUID and COPYUID response codes
  generate_tests_from fixture_file: "uidplus_extension.yml"

  # RFC 5256: THREAD response
  generate_tests_from fixture_file: "thread_responses.yml"

  # RFC 7164: CONDSTORE and QRESYNC responses
  generate_tests_from fixture_file: "rfc7162_condstore_qresync_responses.yml"

  # RFC 8474: OBJECTID responses
  generate_tests_from fixture_file: "rfc8474_objectid_responses.yml"

  # RFC 9208: QUOTA extension
  generate_tests_from fixture_file: "rfc9208_quota_responses.yml"

  ############################################################################
  # Workarounds or unspecified extensions:
  generate_tests_from fixture_file: "quirky_behaviors.yml"

  ############################################################################
  # More interesting tests about the behavior, either of the test or of the
  # response data, should still use normal tests, below
  ############################################################################

  test "default config inherits from Config.global" do
    parser = Net::IMAP::ResponseParser.new
    refute parser.config.frozen?
    refute_equal Net::IMAP::Config.global, parser.config
    assert_same  Net::IMAP::Config.global, parser.config.parent
  end

  test "config can be passed in to #initialize" do
    config = Net::IMAP::Config.global.new
    parser = Net::IMAP::ResponseParser.new config: config
    assert_same config, parser.config
  end

  test "passing in global config inherits from Config.global" do
    parser = Net::IMAP::ResponseParser.new config: Net::IMAP::Config.global
    refute parser.config.frozen?
    refute_equal Net::IMAP::Config.global, parser.config
    assert_same  Net::IMAP::Config.global, parser.config.parent
  end

  test "config will inherits from passed in frozen config" do
    parser = Net::IMAP::ResponseParser.new config: {debug: true}
    refute_equal Net::IMAP::Config.global, parser.config.parent
    refute parser.config.frozen?

    assert parser.config.parent.frozen?
    assert parser.config.debug?
    assert parser.config.inherited?(:debug)

    config = Net::IMAP::Config[debug: true]
    parser = Net::IMAP::ResponseParser.new(config: config)
    refute_equal Net::IMAP::Config.global, parser.config.parent
    assert_same  config, parser.config.parent
  end

  # Strangly, there are no example responses for BINARY[section] in either
  # RFC3516 or RFC9051!  The closest I found was RFC5259, and those examples
  # aren't FETCH responses.
  def test_fetch_binary_and_binary_size
    debug, Net::IMAP.debug = Net::IMAP.debug, true
    png      = File.binread(File.join(TEST_FIXTURE_PATH, "ruby.png"))
    size     = png.bytesize
    parser   = Net::IMAP::ResponseParser.new
    # with literal8
    response = "* 1 FETCH (UID 5 BINARY[3.2] ~{%d}\r\n%s)\r\n".b % [size, png]
    parsed   = parser.parse response
    assert_equal png,              parsed.data.attr["BINARY[3.2]"]
    assert_equal png,              parsed.data.binary(3, 2)
    assert_equal png.bytesize,     parsed.data.attr["BINARY[3.2]"].bytesize
    assert_equal Encoding::BINARY, parsed.data.attr["BINARY[3.2]"].encoding
    # binary.size and partial
    partial  = png[0, 32]
    response = "* 1 FETCH (BINARY.SIZE[5] %d BINARY[5]<0> ~{32}\r\n%s)\r\n".b %
      [png.bytesize, partial]
    parsed   = parser.parse response
    assert_equal png.bytesize, parsed.data.attr["BINARY.SIZE[5]"]
    assert_equal png.bytesize, parsed.data.binary_size(5)
    assert_equal 32,           parsed.data.attr["BINARY[5]<0>"].bytesize
    assert_equal partial,      parsed.data.attr["BINARY[5]<0>"]
    assert_equal partial,      parsed.data.binary(5, offset: 0)
    # test every type of value
    literal8 = "\x00 to \xff\r\n".b * 8
    literal  = "\x01 to \xff\r\n".b * 8
    quoted   = "\x01 to \x7f\b\t".b * 8
    response = "* 1 FETCH (" \
               "BINARY[1] ~{%d}\r\n%s " \
               "BINARY[2] {%d}\r\n%s " \
               "BINARY[3] \"%s\" " \
               "BINARY[4] NIL)\r\n".b % [
                 literal8.bytesize, literal8, literal.bytesize, literal, quoted
               ]
    parsed   = parser.parse response
    assert_equal literal8, parsed.data.attr["BINARY[1]"]
    assert_equal literal8, parsed.data.binary(1)
    assert_equal literal,  parsed.data.attr["BINARY[2]"]
    assert_equal literal,  parsed.data.binary(2)
    assert_equal quoted,   parsed.data.attr["BINARY[3]"]
    assert_equal quoted,   parsed.data.binary(3)
    assert_nil             parsed.data.attr["BINARY[4]"]
    assert_nil             parsed.data.binary(4)
  ensure
    Net::IMAP.debug = debug
  end

end
