# frozen_string_literal: true

require "net/imap"
require "test/unit"

class ThreadMemberTest < Test::Unit::TestCase

  test "#to_sequence_set" do
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
