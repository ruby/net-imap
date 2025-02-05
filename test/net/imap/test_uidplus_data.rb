# frozen_string_literal: true

require "net/imap"
require "test/unit"

class TestUIDPlusData < Test::Unit::TestCase

  test "#uid_mapping with sorted source_uids" do
    uidplus = Net::IMAP::UIDPlusData.new(
      1, [19, 20, *(495..500)], [*(92..97), 100, 101],
    )
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
      uidplus.uid_mapping
    )
  end

  test "#uid_mapping for with source_uids in unsorted order" do
    uidplus = Net::IMAP::UIDPlusData.new(
      1, [*(495..500), 19, 20], [*(92..97), 100, 101],
    )
    assert_equal(
      {
        495 =>  92,
        496 =>  93,
        497 =>  94,
        498 =>  95,
        499 =>  96,
        500 =>  97,
         19 => 100,
         20 => 101,
      },
      uidplus.uid_mapping
    )
  end

end
