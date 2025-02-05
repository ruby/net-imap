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

class TestAppendUIDData < Test::Unit::TestCase
  # alias for convenience
  AppendUIDData = Net::IMAP::AppendUIDData
  SequenceSet = Net::IMAP::SequenceSet
  DataFormatError = Net::IMAP::DataFormatError
  UINT32_MAX = 2**32 - 1

  test "#uidvalidity must be valid nz-number" do
    assert_equal 1, AppendUIDData.new(1, 99).uidvalidity
    assert_equal UINT32_MAX, AppendUIDData.new(UINT32_MAX, 1).uidvalidity
    assert_raise DataFormatError do AppendUIDData.new(0,     1) end
    assert_raise DataFormatError do AppendUIDData.new(2**32, 1) end
  end

  test "#assigned_uids must be a valid uid-set" do
    assert_equal SequenceSet[1],    AppendUIDData.new(99, "1").assigned_uids
    assert_equal SequenceSet[1..9], AppendUIDData.new(1, "1:9").assigned_uids
    assert_equal(SequenceSet[UINT32_MAX],
                 AppendUIDData.new(1, UINT32_MAX.to_s).assigned_uids)
    assert_raise DataFormatError do AppendUIDData.new(1,     0) end
    assert_raise DataFormatError do AppendUIDData.new(1,   "*") end
    assert_raise DataFormatError do AppendUIDData.new(1, "1:*") end
  end

  test "#size returns the number of UIDs" do
    assert_equal(10, AppendUIDData.new(1, "1:10").size)
    assert_equal(4_000_000_000, AppendUIDData.new(1, 1..4_000_000_000).size)
  end

  test "#assigned_uids is converted to SequenceSet" do
    assert_equal SequenceSet[1],    AppendUIDData.new(99, "1").assigned_uids
    assert_equal SequenceSet[1..4], AppendUIDData.new(1, [1, 2, 3, 4]).assigned_uids
  end

end
