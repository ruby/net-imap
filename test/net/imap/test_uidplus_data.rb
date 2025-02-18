# frozen_string_literal: true

require "net/imap"
require "test/unit"

class TestAppendUIDData < Net::IMAP::TestCase
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

class TestCopyUIDData < Net::IMAP::TestCase
  # alias for convenience
  CopyUIDData = Net::IMAP::CopyUIDData
  SequenceSet = Net::IMAP::SequenceSet
  DataFormatError = Net::IMAP::DataFormatError
  UINT32_MAX = 2**32 - 1

  test "#uidvalidity must be valid nz-number" do
    assert_equal 1, CopyUIDData.new(1, 99, 99).uidvalidity
    assert_equal UINT32_MAX, CopyUIDData.new(UINT32_MAX, 1, 1).uidvalidity
    assert_raise DataFormatError do CopyUIDData.new(0,     1, 1) end
    assert_raise DataFormatError do CopyUIDData.new(2**32, 1, 1) end
  end

  test "#source_uids must be valid uid-set" do
    assert_equal SequenceSet[1],    CopyUIDData.new(99, "1", 99).source_uids
    assert_equal SequenceSet[5..8], CopyUIDData.new(1, 5..8, 1..4).source_uids
    assert_equal(SequenceSet[UINT32_MAX],
                 CopyUIDData.new(1, UINT32_MAX.to_s, 1).source_uids)
    assert_raise DataFormatError do CopyUIDData.new(99, nil, 99) end
    assert_raise DataFormatError do CopyUIDData.new(1,     0, 1) end
    assert_raise DataFormatError do CopyUIDData.new(1,   "*", 1) end
  end

  test "#assigned_uids must be a valid uid-set" do
    assert_equal SequenceSet[1],    CopyUIDData.new(99, 1, "1").assigned_uids
    assert_equal SequenceSet[1..9], CopyUIDData.new(1, 1..9, "1:9").assigned_uids
    assert_equal(SequenceSet[UINT32_MAX],
                 CopyUIDData.new(1, 1, UINT32_MAX.to_s).assigned_uids)
    assert_raise DataFormatError do CopyUIDData.new(1, 1,     0) end
    assert_raise DataFormatError do CopyUIDData.new(1, 1,   "*") end
    assert_raise DataFormatError do CopyUIDData.new(1, 1, "1:*") end
  end

  test "#size returns the number of UIDs" do
    assert_equal(10, CopyUIDData.new(1, "9,8,7,6,1:5,10", "1:10").size)
    assert_equal(4_000_000_000,
                 CopyUIDData.new(
                   1, "2000000000:4000000000,1:1999999999", 1..4_000_000_000
                 ).size)
  end

  test "#source_uids and #assigned_uids must be same size" do
    assert_raise DataFormatError do CopyUIDData.new(1, 1..5, 1) end
    assert_raise DataFormatError do CopyUIDData.new(1, 1, 1..5) end
  end

  test "#source_uids is converted to SequenceSet" do
    assert_equal SequenceSet[1],          CopyUIDData.new(99, "1", 99).source_uids
    assert_equal SequenceSet[5, 6, 7, 8], CopyUIDData.new(1, 5..8, 1..4).source_uids
  end

  test "#assigned_uids is converted to SequenceSet" do
    assert_equal SequenceSet[1],          CopyUIDData.new(99, 1, "1").assigned_uids
    assert_equal SequenceSet[1, 2, 3, 4], CopyUIDData.new(1, "1:4", 1..4).assigned_uids
  end

  test "#uid_mapping maps source_uids to assigned_uids" do
    uidplus = CopyUIDData.new(9999, "20:19,500:495", "92:97,101:100")
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
    uidplus = CopyUIDData.new(1, "495:500,20:19", "92:97,101:100")
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

  test "#assigned_uid_for(source_uid)" do
    uidplus = CopyUIDData.new(1, "495:500,20:19", "92:97,101:100")
    assert_equal  92, uidplus.assigned_uid_for(495)
    assert_equal  93, uidplus.assigned_uid_for(496)
    assert_equal  94, uidplus.assigned_uid_for(497)
    assert_equal  95, uidplus.assigned_uid_for(498)
    assert_equal  96, uidplus.assigned_uid_for(499)
    assert_equal  97, uidplus.assigned_uid_for(500)
    assert_equal 100, uidplus.assigned_uid_for( 19)
    assert_equal 101, uidplus.assigned_uid_for( 20)
  end

  test "#[](source_uid)" do
    uidplus = CopyUIDData.new(1, "495:500,20:19", "92:97,101:100")
    assert_equal  92, uidplus[495]
    assert_equal  93, uidplus[496]
    assert_equal  94, uidplus[497]
    assert_equal  95, uidplus[498]
    assert_equal  96, uidplus[499]
    assert_equal  97, uidplus[500]
    assert_equal 100, uidplus[ 19]
    assert_equal 101, uidplus[ 20]
  end

  test "#source_uid_for(assigned_uid)" do
    uidplus = CopyUIDData.new(1, "495:500,20:19", "92:97,101:100")
    assert_equal 495, uidplus.source_uid_for( 92)
    assert_equal 496, uidplus.source_uid_for( 93)
    assert_equal 497, uidplus.source_uid_for( 94)
    assert_equal 498, uidplus.source_uid_for( 95)
    assert_equal 499, uidplus.source_uid_for( 96)
    assert_equal 500, uidplus.source_uid_for( 97)
    assert_equal  19, uidplus.source_uid_for(100)
    assert_equal  20, uidplus.source_uid_for(101)
  end

  test "#each_uid_pair" do
    uidplus = CopyUIDData.new(1, "495:500,20:19", "92:97,101:100")
    expected = {
      495 =>  92,
      496 =>  93,
      497 =>  94,
      498 =>  95,
      499 =>  96,
      500 =>  97,
       19 => 100,
       20 => 101,
    }
    actual = {}
    uidplus.each_uid_pair do |src, dst| actual[src] = dst end
    assert_equal expected, actual
    assert_equal expected,      uidplus.each_uid_pair.to_h
    assert_equal expected.to_a, uidplus.each_uid_pair.to_a
    assert_equal expected,      uidplus.each_pair.to_h
    assert_equal expected,      uidplus.each.to_h
  end

end
