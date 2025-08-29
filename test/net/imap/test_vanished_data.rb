# frozen_string_literal: true

require "net/imap"
require "test/unit"

class VanishedDataTest < Net::IMAP::TestCase
  VanishedData    = Net::IMAP::VanishedData
  SequenceSet     = Net::IMAP::SequenceSet
  DataFormatError = Net::IMAP::DataFormatError

  test ".new(uids: string, earlier: bool)" do
    vanished = VanishedData.new(uids: "1,3:5,7", earlier: true)
    assert_equal SequenceSet["1,3:5,7"], vanished.uids
    assert vanished.earlier?
    vanished = VanishedData.new(uids: "99,111", earlier: false)
    assert_equal SequenceSet["99,111"], vanished.uids
    refute vanished.earlier?
  end

  test ".new, missing args raises ArgumentError" do
    assert_raise ArgumentError do VanishedData.new               end
    assert_raise ArgumentError do VanishedData.new "1234"        end
    assert_raise ArgumentError do VanishedData.new uids: "1234"  end
    assert_raise ArgumentError do VanishedData.new earlier: true end
  end

  test ".new, nil uids raises DataFormatError" do
    assert_raise DataFormatError do VanishedData.new uids: nil, earlier: true end
    assert_raise DataFormatError do VanishedData.new nil, true end
  end

  test ".[uids: string, earlier: bool]" do
    vanished = VanishedData[uids: "1,3:5,7", earlier: true]
    assert_equal SequenceSet["1,3:5,7"], vanished.uids
    assert vanished.earlier?
    vanished = VanishedData[uids: "99,111", earlier: false]
    assert_equal SequenceSet["99,111"], vanished.uids
    refute vanished.earlier?
  end

  test ".[uids, earlier]" do
    vanished = VanishedData["1,3:5,7", true]
    assert_equal SequenceSet["1,3:5,7"], vanished.uids
    assert vanished.earlier?
    vanished = VanishedData["99,111", false]
    assert_equal SequenceSet["99,111"], vanished.uids
    refute vanished.earlier?
  end

  test ".[], mixing args raises ArgumentError" do
    assert_raise ArgumentError do
      VanishedData[1, true, uids: "1", earlier: true]
    end
    assert_raise ArgumentError do VanishedData["1234", earlier: true] end
    assert_raise ArgumentError do VanishedData[nil, true, uids: "1"]  end
  end

  test ".[], missing args raises ArgumentError" do
    assert_raise ArgumentError do VanishedData[]             end
    assert_raise ArgumentError do VanishedData["1234"]       end
  end

  test ".[], nil uids raises DataFormatError" do
    assert_raise DataFormatError do VanishedData[nil,    true] end
    assert_raise DataFormatError do VanishedData[nil,     nil] end
  end

  test "#to_a delegates to uids (SequenceSet#to_a)" do
    assert_equal [1, 2, 3, 4], VanishedData["1:4", true].to_a
  end

  test "#deconstruct_keys returns uids and earlier" do
    assert_equal({uids: SequenceSet[1,9], earlier: true},
                 VanishedData["1,9", true].deconstruct_keys([:uids, :earlier]))
    VanishedData["1:5", false] => VanishedData[uids: SequenceSet, earlier: false]
  end

  test "#==" do
    assert_equal VanishedData[123,   false], VanishedData["123", false]
    assert_equal VanishedData["3:1", false], VanishedData["1:3", false]
  end

  test "#eql?" do
    assert VanishedData["1:3", false].eql?(VanishedData[1..3, false])
    refute VanishedData["3:1", false].eql?(VanishedData["1:3", false])
    refute VanishedData["1:5", false].eql?(VanishedData["1:3", false])
    refute VanishedData["1:3",  true].eql?(VanishedData["1:3", false])
  end

end
