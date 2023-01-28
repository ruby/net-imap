# frozen_string_literal: true

require "net/imap"
require "test/unit"

class IMAPResponseDataTest < Test::Unit::TestCase

  def setup
    @do_not_reverse_lookup = Socket.do_not_reverse_lookup
    Socket.do_not_reverse_lookup = true
  end

  def teardown
    Socket.do_not_reverse_lookup = @do_not_reverse_lookup
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

  def test_thread_member_to_sequence_set
    # copied from the fourth example in RFC5256: (3 6 (4 23)(44 7 96))
    thmember = Net::IMAP::ThreadMember.method :new
    thread = thmember.(3, [
      thmember.(6, [
        thmember.(4, [
          thmember.(23, [])
        ]),
        thmember.(44, [
          thmember.(7, [
            thmember.(96, [])
          ])
        ])
      ])
    ])
    expected = Net::IMAP::SequenceSet.new("3:4,6:7,23,44,96")
    assert_equal(expected, thread.to_sequence_set)
  end

end
