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

  # §7.1: Generic Status Responses (OK, NO, BAD, PREAUTH, BYE, codes, text)
  generate_tests_from fixture_file: "resp_text_responses.yml"

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

  ############################################################################
  # Workarounds or unspecified extensions:
  generate_tests_from fixture_file: "quirky_behaviors.yml"

  ############################################################################
  # More interesting tests about the behavior, either of the test or of the
  # response data, should still use normal tests, below
  ############################################################################

  def test_enable
    parser = Net::IMAP::ResponseParser.new
    response = parser.parse("* ENABLED SMTPUTF8\r\n")
    assert_equal("ENABLED", response.name)
    assert_equal(1, response.data.length)
    assert_equal("SMTPUTF8", response.data.first)
  end

  # todo: move this to response data tests file
  # it's testing the mapping fn, not the parsing.
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
