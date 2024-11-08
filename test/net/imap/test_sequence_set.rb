# frozen_string_literal: true

require "net/imap"
require "test/unit"
require "set"

class IMAPSequenceSetTest < Test::Unit::TestCase
  # alias for convenience
  SequenceSet     = Net::IMAP::SequenceSet
  DataFormatError = Net::IMAP::DataFormatError

  def compare_to_reference_set(nums, set, seqset)
    set.merge nums
    seqset.merge nums
    assert_equal set, seqset.to_set
    assert seqset.elements.size <= set.size
    sorted = set.to_a.sort
    assert_equal sorted, seqset.numbers
    Array.new(50) { rand(sorted.count) }.each do |idx|
      assert_equal sorted.at(idx),  seqset.at(idx)
      assert_equal sorted.at(-idx), seqset.at(-idx)
    end
    assert seqset.cover? sorted.sample 100
  end

  test "compared to reference Set, add many random values" do
    set    = Set.new
    seqset = SequenceSet.new
    10.times do
      nums = Array.new(1000) { rand(1..10_000) }
      compare_to_reference_set(nums, set, seqset)
    end
  end

  test "compared to reference Set, add many large ranges" do
    set    = Set.new
    seqset = SequenceSet.new
    (1..10_000).each_slice(250) do
      compare_to_reference_set _1, set, seqset
      assert_equal 1, seqset.elements.size
    end
  end

  test "#== equality by value (not by identity or representation)" do
    assert_equal SequenceSet.new, SequenceSet.new
    assert_equal SequenceSet.new("1"), SequenceSet[1]
    assert_equal SequenceSet.new("*"), SequenceSet[:*]
    assert_equal SequenceSet["2:4"], SequenceSet["4:2"]
  end

  test "#freeze" do
    set = SequenceSet.new "2:4,7:11,99,999"
    assert !set.frozen?
    set.freeze
    assert set.frozen?
    assert Ractor.shareable?(set) if defined?(Ractor)
    assert_equal set, set.freeze
  end

  data "#clear",       :clear
  data "#replace seq", ->{ _1.replace SequenceSet[1] }
  data "#replace num", ->{ _1.replace   1 }
  data "#replace str", ->{ _1.replace  ?1 }
  data "#string=",     ->{ _1.string = ?1 }
  data "#add",         ->{ _1.add       1 }
  data "#add?",        ->{ _1.add?      1 }
  data "#<<",          ->{ _1 <<        1 }
  data "#append",      ->{ _1.append    1 }
  data "#delete",      ->{ _1.delete    3 }
  data "#delete?",     ->{ _1.delete?   3 }
  data "#delete_at",   ->{ _1.delete_at 3 }
  data "#slice!",      ->{ _1.slice!    1 }
  data "#merge",       ->{ _1.merge     1 }
  data "#subtract",    ->{ _1.subtract  1 }
  data "#limit!",      ->{ _1.limit! max: 10 }
  data "#complement!", :complement!
  data "#normalize!",  :normalize!
  test "frozen error message" do |modification|
    set = SequenceSet["2:4,7:11,99,999"]
    msg = "can't modify frozen Net::IMAP::SequenceSet: %p" % [set]
    assert_raise_with_message FrozenError, msg do
      modification.to_proc.(set)
    end
  end

  %i[clone dup].each do |method|
    test "##{method}" do
      orig = SequenceSet.new "2:4,7:11,99,999"
      copy = orig.send method
      assert_equal orig, copy
      orig << 123
      copy << 456
      assert_not_equal orig, copy
      assert  orig.include?(123)
      assert  copy.include?(456)
      assert !copy.include?(123)
      assert !orig.include?(456)
    end
  end

  if defined?(Ractor)
    test "#freeze makes ractor sharable (deeply frozen)" do
      assert Ractor.shareable? SequenceSet.new("1:9,99,999").freeze
    end

    test ".[] returns ractor sharable (deeply frozen)" do
      assert Ractor.shareable? SequenceSet["2:8,88,888"]
    end

    test "#clone preserves ractor sharability (deeply frozen)" do
      assert Ractor.shareable? SequenceSet["3:7,77,777"].clone
    end
  end

  test ".new, input must be valid" do
    assert_raise DataFormatError do SequenceSet.new [0]          end
    assert_raise DataFormatError do SequenceSet.new "0"          end
    assert_raise DataFormatError do SequenceSet.new [2**32]      end
    assert_raise DataFormatError do SequenceSet.new [2**33]      end
    assert_raise DataFormatError do SequenceSet.new (2**32).to_s end
    assert_raise DataFormatError do SequenceSet.new (2**33).to_s end
    assert_raise DataFormatError do SequenceSet.new "0:2"        end
    assert_raise DataFormatError do SequenceSet.new ":2"         end
    assert_raise DataFormatError do SequenceSet.new " 2"         end
    assert_raise DataFormatError do SequenceSet.new "2 "         end
    assert_raise DataFormatError do SequenceSet.new "2,"         end
    assert_raise DataFormatError do SequenceSet.new Time.now     end
  end

  test ".[frozen SequenceSet] returns that SequenceSet" do
    frozen_seqset = SequenceSet[123..456]
    assert_same frozen_seqset, SequenceSet[frozen_seqset]
  end

  test ".new, input may be empty" do
    assert_empty SequenceSet.new
    assert_empty SequenceSet.new []
    assert_empty SequenceSet.new [[]]
    assert_empty SequenceSet.new nil
    assert_empty SequenceSet.new ""
  end

  test ".[] must not be empty" do
    assert_raise ArgumentError   do SequenceSet[]     end
    assert_raise DataFormatError do SequenceSet[[]]   end
    assert_raise DataFormatError do SequenceSet[[[]]] end
    assert_raise DataFormatError do SequenceSet[nil]  end
    assert_raise DataFormatError do SequenceSet[""]   end
  end

  test ".try_convert" do
    assert_nil SequenceSet.try_convert(nil)
    assert_nil SequenceSet.try_convert(123)
    assert_nil SequenceSet.try_convert(12..34)
    assert_nil SequenceSet.try_convert("12:34")
    assert_nil SequenceSet.try_convert(Object.new)

    obj = Object.new
    def obj.to_sequence_set; SequenceSet[192, 168, 1, 255] end
    assert_equal SequenceSet[192, 168, 1, 255], SequenceSet.try_convert(obj)

    obj = Object.new
    def obj.to_sequence_set; 192_168.001_255 end
    assert_raise DataFormatError do SequenceSet.try_convert(obj) end
  end

  test "#[non-negative index]" do
    assert_nil        SequenceSet.empty[0]
    assert_equal   1, SequenceSet[1..][0]
    assert_equal   1, SequenceSet.full[0]
    assert_equal 111, SequenceSet.full[110]
    assert_equal   4, SequenceSet[2,4,6,8][1]
    assert_equal   8, SequenceSet[2,4,6,8][3]
    assert_equal   6, SequenceSet[4..6][2]
    assert_nil        SequenceSet[4..6][3]
    assert_equal 205, SequenceSet["101:110,201:210,301:310"][14]
    assert_equal 310, SequenceSet["101:110,201:210,301:310"][29]
    assert_nil        SequenceSet["101:110,201:210,301:310"][44]
    assert_equal  :*, SequenceSet["1:10,*"][10]
  end

  test "#[negative index]" do
    assert_nil        SequenceSet.empty[0]
    assert_equal  :*, SequenceSet[1..][-1]
    assert_equal   1, SequenceSet.full[-(2**32)]
    assert_equal 111, SequenceSet[1..111][-1]
    assert_equal   4, SequenceSet[2,4,6,8][1]
    assert_equal   8, SequenceSet[2,4,6,8][3]
    assert_equal   6, SequenceSet[4..6][2]
    assert_nil        SequenceSet[4..6][3]
    assert_equal 205, SequenceSet["101:110,201:210,301:310"][14]
    assert_equal 310, SequenceSet["101:110,201:210,301:310"][29]
    assert_nil        SequenceSet["101:110,201:210,301:310"][44]
  end

  test "#[start, length]" do
    assert_equal SequenceSet[10..99], SequenceSet.full[9, 90]
    assert_equal 90, SequenceSet.full[9, 90].count
    assert_equal SequenceSet[1000..1099],
                 SequenceSet[1..100, 1000..1111][100, 100]
    assert_equal SequenceSet[11, 21, 31, 41],
                 SequenceSet[((1..10_000) % 10).to_a][1, 4]
    assert_equal SequenceSet[9981, 9971, 9961, 9951],
                 SequenceSet[((1..10_000) % 10).to_a][-5, 4]
    assert_nil SequenceSet[111..222, 888..999][2000, 4]
    assert_nil SequenceSet[111..222, 888..999][-2000, 4]
  end

  test "#[range]" do
    assert_equal SequenceSet[10..100], SequenceSet.full[9..99]
    assert_equal SequenceSet[1000..1100],
                 SequenceSet[1..100, 1000..1111][100..200]
    assert_equal SequenceSet[1000..1099],
                 SequenceSet[1..100, 1000..1111][100...200]
    assert_equal SequenceSet[11, 21, 31, 41],
                 SequenceSet[((1..10_000) % 10).to_a][1..4]
    assert_equal SequenceSet[9981, 9971, 9961, 9951],
                 SequenceSet[((1..10_000) % 10).to_a][-5..-2]
    assert_equal SequenceSet[((51..9951) % 10).to_a],
                 SequenceSet[((1..10_000) % 10).to_a][5..-5]
    assert_equal SequenceSet.full, SequenceSet.full[0..]
    assert_equal SequenceSet[2..], SequenceSet.full[1..]
    assert_equal SequenceSet[:*], SequenceSet.full[-1..]
    assert_equal SequenceSet.empty, SequenceSet[1..100][60..50]
    assert_equal SequenceSet.empty, SequenceSet[1..100][-50..-60]
    assert_equal SequenceSet.empty, SequenceSet[1..100][-10..10]
    assert_equal SequenceSet.empty, SequenceSet[1..100][60..-60]
    assert_nil SequenceSet.empty[2..4]
    assert_nil SequenceSet[101..200][1000..1060]
    assert_nil SequenceSet[101..200][-1000..-60]
  end

  test "#find_index" do
    assert_equal   9, SequenceSet.full.find_index(10)
    assert_equal  99, SequenceSet.full.find_index(100)
    set = SequenceSet[1..100, 1000..1111]
    assert_equal 100, set.find_index(1000)
    assert_equal 200, set.find_index(1100)
    set = SequenceSet[((1..10_000) % 10).to_a]
    assert_equal   0, set.find_index(1)
    assert_equal   1, set.find_index(11)
    assert_equal   5, set.find_index(51)
    assert_nil SequenceSet.empty.find_index(1)
    assert_nil SequenceSet[5..9].find_index(4)
    assert_nil SequenceSet[5..9,12..24].find_index(10)
    assert_nil SequenceSet[5..9,12..24].find_index(11)
    assert_equal         1, SequenceSet[1, :*].find_index(-1)
    assert_equal 2**32 - 1, SequenceSet.full.find_index(:*)
  end

  test "#limit" do
    set = SequenceSet["1:100,500"]
    assert_equal [1..99],               set.limit(max: 99).ranges
    assert_equal (1..15).to_a,          set.limit(max: 15).numbers
    assert_equal SequenceSet["1:100"],  set.limit(max: 101)
    assert_equal SequenceSet["1:97"],   set.limit(max: 97)
    assert_equal [1..99],               set.limit(max: 99).ranges
    assert_equal (1..15).to_a,          set.limit(max: 15).numbers
  end

  test "#limit with *" do
    assert_equal SequenceSet.new("2,4,5,6,7,9,12,13,14,15"),
                 SequenceSet.new("2,4:7,9,12:*").limit(max: 15)
    assert_equal(SequenceSet["37"],
                 SequenceSet["50,60,99:*"].limit(max: 37))
    assert_equal(SequenceSet["1:100,300"],
                 SequenceSet["1:100,500:*"].limit(max: 300))
    assert_equal [15], SequenceSet["3967:*"].limit(max: 15).numbers
    assert_equal [15], SequenceSet["*:12293456"].limit(max: 15).numbers
  end

  test "#limit with empty result" do
    assert_equal SequenceSet.empty, SequenceSet["1234567890"].limit(max: 37)
    assert_equal SequenceSet.empty, SequenceSet["99:195,458"].limit(max: 37)
  end

  test "values for '*'" do
    assert_equal "*",   SequenceSet[?*].to_s
    assert_equal "*",   SequenceSet[:*].to_s
    assert_equal "*",   SequenceSet[-1].to_s
    assert_equal "*",   SequenceSet[[?*]].to_s
    assert_equal "*",   SequenceSet[[:*]].to_s
    assert_equal "*",   SequenceSet[[-1]].to_s
    assert_equal "1:*", SequenceSet[1..].to_s
    assert_equal "1:*", SequenceSet[1..-1].to_s
  end

  test "#empty?" do
    refute SequenceSet.new("1:*").empty?
    refute SequenceSet.new(:*).empty?
    assert SequenceSet.new(nil).empty?
    assert SequenceSet.new.empty?
    assert SequenceSet.empty.empty?
    set = SequenceSet.new "1:1111"
    refute set.empty?
    set.string = nil
    assert set.empty?
  end

  test "#full?" do
    assert SequenceSet.new("1:*").full?
    refute SequenceSet.new(1..2**32-1).full?
    refute SequenceSet.new(nil).full?
  end

  test "#to_sequence_set" do
    assert_equal (set = SequenceSet["*"]),              set.to_sequence_set
    assert_equal (set = SequenceSet["15:36,5,99,*,2"]), set.to_sequence_set
  end

  test "set + other" do
    seqset = -> { SequenceSet.new _1 }
    assert_equal seqset["1,5"],       seqset["1"]         + seqset["5"]
    assert_equal seqset["1,*"],       seqset["*"]         + seqset["1"]
    assert_equal seqset["1:*"],       seqset["1:4"]       + seqset["5:*"]
    assert_equal seqset["1:*"],       seqset["5:*"]       + seqset["1:4"]
    assert_equal seqset["1:5"],       seqset["1,3,5"]     + seqset["2,4"]
    assert_equal seqset["1:3,5,7:9"], seqset["1,3,5,7:8"] + seqset["2,8:9"]
    assert_equal seqset["1:*"],       seqset["1,3,5,7:*"] + seqset["2,4:6"]
  end

  test "#add" do
    assert_equal SequenceSet["1,5"], SequenceSet.new("1").add("5")
    assert_equal SequenceSet["1,*"], SequenceSet.new("*").add(1)
    assert_equal SequenceSet["1:9"], SequenceSet.new("1:6").add("4:9")
    assert_equal SequenceSet["1:*"], SequenceSet.new("1:4").add(5..)
    assert_equal SequenceSet["1:*"], SequenceSet.new("5:*").add(1..4)
  end

  test "#<<" do
    assert_equal SequenceSet["1,5"], SequenceSet.new("1")   << "5"
    assert_equal SequenceSet["1,*"], SequenceSet.new("*")   << 1
    assert_equal SequenceSet["1:9"], SequenceSet.new("1:6") << "4:9"
    assert_equal SequenceSet["1:*"], SequenceSet.new("1:4") << (5..)
    assert_equal SequenceSet["1:*"], SequenceSet.new("5:*") << (1..4)
  end

  test "#append" do
    assert_equal "1,5",     SequenceSet.new("1").append("5").string
    assert_equal "*,1",     SequenceSet.new("*").append(1).string
    assert_equal "1:6,4:9", SequenceSet.new("1:6").append("4:9").string
    assert_equal "1:4,5:*", SequenceSet.new("1:4").append(5..).string
    assert_equal "5:*,1:4", SequenceSet.new("5:*").append(1..4).string
  end

  test "#merge" do
    seqset = -> { SequenceSet.new _1 }
    assert_equal seqset["1,5"],       seqset["1"].merge("5")
    assert_equal seqset["1,*"],       seqset["*"].merge(1)
    assert_equal seqset["1:*"],       seqset["1:4"].merge(5..)
    assert_equal seqset["1:3,5,7:9"], seqset["1,3,5,7:8"].merge(seqset["2,8:9"])
    assert_equal seqset["1:*"],       seqset["5:*"].merge(1..4)
    assert_equal seqset["1:5"],       seqset["1,3,5"].merge(seqset["2,4"])
  end

  test "set - other" do
    seqset = -> { SequenceSet.new _1 }
    assert_equal seqset["1,5"],       seqset["1,5"] - 9
    assert_equal seqset["1,5"],       seqset["1,5"] - "3"
    assert_equal seqset["1,5"],       seqset["1,3,5"] - [3]
    assert_equal seqset["1,9"],       seqset["1,3:9"] - "2:8"
    assert_equal seqset["1,9"],       seqset["1:7,9"] - (2..8)
    assert_equal seqset["1,9"],       seqset["1:9"] - (2..8).to_a
    assert_equal seqset["1,5"],       seqset["1,5:9,11:99"] - "6:999"
    assert_equal seqset["1,5,99"],    seqset["1,5:9,11:88,99"] - ["6:98"]
    assert_equal seqset["1,5,99"],    seqset["1,5:6,8:9,11:99"] - "6:98"
    assert_equal seqset["1,5,11:99"], seqset["1,5:6,8:9,11:99"] - "6:9"
    assert_equal seqset["1:10"],      seqset["1:*"] - (11..)
    assert_equal seqset[nil],         seqset["1,5"] - [1..8, 10..]
  end

  test "#intersection" do
    seqset = -> { SequenceSet.new _1 }
    assert_equal seqset[nil],         seqset["1,5"] & "9"
    assert_equal seqset["1,5"],       seqset["1:5"].intersection([1, 5..9])
    assert_equal seqset["1,5"],       seqset["1:5"] & [1, 5, 9, 55]
    assert_equal seqset["*"],         seqset["9999:*"] & "1,5,9,*"
  end

  test "#intersect?" do
    set = SequenceSet["1:5,11:20"]
    refute set.intersect? "9"
    refute set.intersect? 9
    refute set.intersect? 6..10
    refute set.intersect? ~set
    assert set.intersect? 6..11
    assert set.intersect? "1,5,11,20"
    assert set.intersect? set
  end

  test "#disjoint?" do
    set = SequenceSet["1:5,11:20"]
    assert set.disjoint? "9"
    assert set.disjoint? 6..10
    assert set.disjoint? ~set
    refute set.disjoint? 6..11
    refute set.disjoint? "1,5,11,20"
    refute set.disjoint? set
  end

  test "#delete" do
    seqset = -> { SequenceSet.new _1 }
    assert_equal seqset["1,5"],       seqset["1,5"].delete("9")
    assert_equal seqset["1,5"],       seqset["1,5"].delete("3")
    assert_equal seqset["1,5"],       seqset["1,3,5"].delete("3")
    assert_equal seqset["1,9"],       seqset["1,3:9"].delete("2:8")
    assert_equal seqset["1,9"],       seqset["1:7,9"].delete("2:8")
    assert_equal seqset["1,9"],       seqset["1:9"].delete("2:8")
    assert_equal seqset["1,5"],       seqset["1,5:9,11:99"].delete("6:999")
    assert_equal seqset["1,5,99"],    seqset["1,5:9,11:88,99"].delete("6:98")
    assert_equal seqset["1,5,99"],    seqset["1,5:6,8:9,11:99"].delete("6:98")
    assert_equal seqset["1,5,11:99"], seqset["1,5:6,8:9,11:99"].delete("6:9")
  end

  test "#subtract" do
    seqset = -> { SequenceSet.new _1 }
    assert_equal seqset["1,5"],       seqset["1,5"].subtract("9")
    assert_equal seqset["1,5"],       seqset["1,5"].subtract("3")
    assert_equal seqset["1,5"],       seqset["1,3,5"].subtract("3")
    assert_equal seqset["1,9"],       seqset["1,3:9"].subtract("2:8")
    assert_equal seqset["1,9"],       seqset["1:7,9"].subtract("2:8")
    assert_equal seqset["1,9"],       seqset["1:9"].subtract("2:8")
    assert_equal seqset["1,5"],       seqset["1,5:9,11:99"].subtract("6:999")
    assert_equal seqset["1,5,99"],    seqset["1,5:9,11:88,99"].subtract("6:98")
    assert_equal seqset["1,5,99"],    seqset["1,5:6,8:9,11:99"].subtract("6:98")
    assert_equal seqset["1,5,11:99"], seqset["1,5:6,8:9,11:99"].subtract("6:9")
  end

  test "#min" do
    assert_equal   3, SequenceSet.new("34:3").min
    assert_equal 345, SequenceSet.new("345,678").min
    assert_nil        SequenceSet.new.min
  end

  test "#max" do
    assert_equal  34, SequenceSet["34:3"].max
    assert_equal 678, SequenceSet["345,678"].max
    assert_equal 678, SequenceSet["345:678"].max(star: "unused")
    assert_equal  :*, SequenceSet["345:*"].max
    assert_equal nil, SequenceSet["345:*"].max(star: nil)
    assert_equal "*", SequenceSet["345:*"].max(star: "*")
    assert_nil SequenceSet.new.max(star: "ignored")
  end

  test "#minmax" do
    assert_equal [  3,   3], SequenceSet["3"].minmax
    assert_equal [ :*,  :*], SequenceSet["*"].minmax
    assert_equal [ 99,  99], SequenceSet["*"].minmax(star: 99)
    assert_equal [  3,  34], SequenceSet["34:3"].minmax
    assert_equal [345, 678], SequenceSet["345,678"].minmax
    assert_equal [345, 678], SequenceSet["345:678"].minmax(star: "unused")
    assert_equal [345,  :*], SequenceSet["345:*"].minmax
    assert_equal [345, nil], SequenceSet["345:*"].minmax(star: nil)
    assert_equal [345, "*"], SequenceSet["345:*"].minmax(star: "*")
    assert_nil SequenceSet.new.minmax(star: "ignored")
  end

  test "#add?" do
    assert_equal(SequenceSet.new("1:3,5,7:8"),
                 SequenceSet.new("1,3,5,7:8").add?("2"))
    assert_equal(SequenceSet.new("1,3,5,7:9"),
                 SequenceSet.new("1,3,5,7:8").add?("8:9"))
    assert_nil   SequenceSet.new("1,3,5,7:*").add?("3")
    assert_nil   SequenceSet.new("1,3,5,7:*").add?("9:91")
  end

  test "#delete?" do
    set = SequenceSet.new [5..10, 20]
    assert_nil   set.delete?(11)
    assert_equal SequenceSet[5..10, 20], set
    assert_equal 6, set.delete?(6)
    assert_equal SequenceSet[5, 7..10, 20], set
    assert_equal SequenceSet[9..10, 20],    set.delete?(9..)
    assert_equal SequenceSet[5, 7..8],      set
    assert_nil   set.delete?(11..)
  end

  test "#slice!" do
    set = SequenceSet.new 1..20
    assert_equal SequenceSet[1..4], set.slice!(0, 4)
    assert_equal SequenceSet[5..20], set
    assert_equal 14, set.slice!(-7)
    assert_equal SequenceSet[5..13, 15..20], set
    assert_equal 11, set.slice!(6)
    assert_equal SequenceSet[5..10, 12..13, 15..20], set
    assert_equal SequenceSet[12..13, 15..19], set.slice!(6..12)
    assert_equal SequenceSet[5..10, 20], set
    assert_nil   set.slice!(10)
    assert_equal SequenceSet[5..10, 20], set
    assert_equal 6, set.slice!(1)
    assert_equal SequenceSet[5, 7..10, 20], set
    assert_equal SequenceSet[9..10, 20],    set.slice!(3..)
    assert_equal SequenceSet[5, 7..8],      set
    assert_nil   set.slice!(3)
    assert_nil   set.slice!(3..)
  end

  test "#delete_at" do
    set = SequenceSet.new [5..10, 20]
    assert_nil   set.delete_at(20)
    assert_equal SequenceSet[5..10, 20], set
    assert_equal   6, set.delete_at(1)
    assert_equal   9, set.delete_at(3)
    assert_equal  10, set.delete_at(3)
    assert_equal  20, set.delete_at(3)
    assert_equal nil, set.delete_at(3)
    assert_equal SequenceSet[5, 7..8], set
  end

  test "#include_star?" do
    assert SequenceSet["2,*:12"].include_star?
    assert SequenceSet[-1].include_star?
    refute SequenceSet["12"].include_star?
  end

  test "#include?" do
    assert SequenceSet["2:4"].include?(3)
    assert SequenceSet["2,*:12"].include? :*
    assert SequenceSet["2,*:12"].include?(-1)
    set = SequenceSet.new Array.new(100) { rand(1..1500) }
    rev = (~set).limit(max: 1_501)
    set.numbers.each do assert set.include?(_1) end
    rev.numbers.each do refute set.include?(_1) end
  end

  test "#cover?" do
    assert SequenceSet["2:4"].cover?(3)
    assert SequenceSet["2,4:7,9,12:*"] === 2
    assert SequenceSet["2,4:7,9,12:*"].cover?(2222)
    assert SequenceSet["2,*:12"].cover? :*
    assert SequenceSet["2,*:12"].cover?(-1)
    assert SequenceSet["2,*:12"].cover?(99..5000)
    refute SequenceSet["2,*:12"].cover?(10)
    refute SequenceSet["2,*:12"].cover?(10..13)
    assert SequenceSet["2:12"].cover?(10..12)
    refute SequenceSet["2:12"].cover?(10..13)
    assert SequenceSet["2:12"].cover?(10...13)
    set = SequenceSet.new Array.new(100) { rand(1..1500) }
    rev = (~set).limit(max: 1_501)
    refute set.cover?(rev)
    set.each_element do assert set.cover?(_1) end
    rev.each_element do refute set.cover?(_1) end
    assert SequenceSet["2:4"].cover? []
    assert SequenceSet["2:4"].cover? SequenceSet.empty
    assert SequenceSet["2:4"].cover? nil
    assert SequenceSet["2:4"].cover? ""
    refute SequenceSet["2:4"].cover? "*"
    refute SequenceSet["2:4"].cover? SequenceSet.full
    assert SequenceSet.full  .cover? SequenceSet.full
    assert SequenceSet.full  .cover? :*
    assert SequenceSet.full  .cover?(-1)
    assert SequenceSet.empty .cover? SequenceSet.empty
    refute SequenceSet.empty .cover? SequenceSet[:*]
  end

  test "~full == empty" do
    assert_equal SequenceSet.new("1:*"), ~SequenceSet.new
    assert_equal SequenceSet.new,        ~SequenceSet.new("1:*")
    assert_equal SequenceSet.new("1:*"),  SequenceSet.new       .complement
    assert_equal SequenceSet.new,         SequenceSet.new("1:*").complement
    assert_equal SequenceSet.new("1:*"),  SequenceSet.new       .complement!
    assert_equal SequenceSet.new,         SequenceSet.new("1:*").complement!
  end

  data(
    # desc         => [expected, input, freeze]
    "empty"        => ["#<Net::IMAP::SequenceSet empty>",   nil],
    "frozen empty" => ["Net::IMAP::SequenceSet.empty",      nil, true],
    "normalized"   => ['#<Net::IMAP::SequenceSet "1:2">',   [2, 1]],
    "denormalized" => ['#<Net::IMAP::SequenceSet "2,1">',   "2,1"],
    "star"         => ['#<Net::IMAP::SequenceSet "*">',     "*"],
    "frozen"       => ['Net::IMAP::SequenceSet["1,3,5:*"]', [1, 3, 5..], true],
  )
  def test_inspect((expected, input, freeze))
    seqset = SequenceSet.new(input)
    seqset = seqset.freeze if freeze
    assert_equal expected, seqset.inspect
  end

  data "single number", {
    input:      "123456",
    elements:   [123_456],
    entries:    [123_456],
    ranges:     [123_456..123_456],
    numbers:    [123_456],
    to_s:       "123456",
    normalize:  "123456",
    count:      1,
    complement: "1:123455,123457:*",
  }, keep: true

  data "single range", {
    input:      "1:3",
    elements:   [1..3],
    entries:    [1..3],
    ranges:     [1..3],
    numbers:    [1, 2, 3],
    to_s:       "1:3",
    normalize:  "1:3",
    count:      3,
    complement: "4:*",
  }, keep: true

  data "simple numbers list", {
    input:      "1,3,5",
    elements:   [   1,    3,    5],
    entries:    [   1,    3,    5],
    ranges:     [1..1, 3..3, 5..5],
    numbers:    [   1,    3,    5],
    to_s:       "1,3,5",
    normalize:  "1,3,5",
    count:      3,
    complement: "2,4,6:*",
  }, keep: true

  data "numbers and ranges list", {
    input:      "1:3,5,7:9,46",
    elements:   [1..3,    5, 7..9,     46],
    entries:    [1..3,    5, 7..9,     46],
    ranges:     [1..3, 5..5, 7..9, 46..46],
    numbers:    [1, 2, 3, 5, 7, 8, 9,  46],
    to_s:       "1:3,5,7:9,46",
    normalize:  "1:3,5,7:9,46",
    count:      8,
    complement: "4,6,10:45,47:*",
  }, keep: true

  data "just *", {
    input:      "*",
    elements:   [:*],
    entries:    [:*],
    ranges:     [:*..],
    numbers:    RangeError,
    to_s:       "*",
    normalize:  "*",
    count:      1,
    complement: "1:%d" % [2**32-1]
  }, keep: true

  data "range with *", {
    input:      "4294967000:*",
    elements:   [4_294_967_000..],
    entries:    [4_294_967_000..],
    ranges:     [4_294_967_000..],
    numbers:    RangeError,
    to_s:       "4294967000:*",
    normalize:  "4294967000:*",
    count:      2**32 - 4_294_967_000,
    complement: "1:4294966999",
  }, keep: true

  data "* sorts last", {
    input:      "5,*,7",
    elements:   [5, 7, :*],
    entries:    [5, :*, 7],
    ranges:     [5..5, 7..7, :*..],
    numbers:    RangeError,
    to_s:       "5,*,7",
    normalize:  "5,7,*",
    complement: "1:4,6,8:%d" % [2**32-1],
    count:      3,
  }, keep: true

  data "out of order", {
    input:      "46,7:6,15,3:1",
    elements:   [1..3, 6..7, 15, 46],
    entries:    [46, 6..7, 15, 1..3],
    ranges:     [1..3, 6..7, 15..15, 46..46],
    numbers:    [1, 2, 3, 6, 7, 15, 46],
    to_s:       "46,7:6,15,3:1",
    normalize:  "1:3,6:7,15,46",
    count:      7,
    complement: "4:5,8:14,16:45,47:*",
  }, keep: true

  data "adjacent", {
    input:      "1,2,3,5,7:9,10:11",
    elements:   [1..3, 5,    7..11],
    entries:    [1, 2, 3, 5, 7..9, 10..11],
    ranges:     [1..3, 5..5, 7..11],
    numbers:    [1, 2, 3, 5, 7, 8, 9, 10, 11],
    to_s:       "1,2,3,5,7:9,10:11",
    normalize:  "1:3,5,7:11",
    count:      9,
    complement: "4,6,12:*",
  }, keep: true

  data "overlapping", {
    input:      "1:5,3:7,10:9,10:11",
    elements:   [1..7, 9..11],
    entries:    [1..5, 3..7, 9..10, 10..11],
    ranges:     [1..7, 9..11],
    numbers:    [1, 2, 3, 4, 5, 6, 7,  9, 10, 11],
    to_s:       "1:5,3:7,10:9,10:11",
    normalize:  "1:7,9:11",
    count:      10,
    complement: "8,12:*",
  }, keep: true

  data "contained", {
    input:      "1:5,3:4,9:11,10",
    elements:   [1..5, 9..11],
    entries:    [1..5, 3..4, 9..11, 10],
    ranges:     [1..5, 9..11],
    numbers:    [1, 2, 3, 4, 5, 9, 10, 11],
    to_s:       "1:5,3:4,9:11,10",
    normalize:  "1:5,9:11",
    count:      8,
    complement: "6:8,12:*",
  }, keep: true

  data "array", {
    input:      ["1:5,3:4", 9..11, "10", 99, :*],
    elements:   [1..5, 9..11, 99, :*],
    entries:    [1..5, 9..11, 99, :*],
    ranges:     [1..5, 9..11, 99..99, :*..],
    numbers:    RangeError,
    to_s:       "1:5,9:11,99,*",
    normalize:  "1:5,9:11,99,*",
    count:      10,
    complement: "6:8,12:98,100:#{2**32 - 1}",
  }, keep: true

  data "nested array", {
    input:      [["1:5", [3..4], [[[9..11, "10"], 99], :*]]],
    elements:   [1..5, 9..11, 99, :*],
    entries:    [1..5, 9..11, 99, :*],
    ranges:     [1..5, 9..11, 99..99, :*..],
    numbers:    RangeError,
    to_s:       "1:5,9:11,99,*",
    normalize:  "1:5,9:11,99,*",
    count:      10,
    complement: "6:8,12:98,100:#{2**32 - 1}",
  }, keep: true

  data "empty", {
    input:      nil,
    elements:   [],
    entries:    [],
    ranges:     [],
    numbers:    [],
    to_s:       "",
    normalize:  nil,
    count:      0,
    complement: "1:*",
  }, keep: true

  test "#elements" do |data|
    assert_equal data[:elements], SequenceSet.new(data[:input]).elements
  end

  test "#each_element" do |data|
    seqset = SequenceSet.new(data[:input])
    array = []
    assert_equal seqset, seqset.each_element { array << _1 }
    assert_equal data[:elements], array
    assert_equal data[:elements], seqset.each_element.to_a
  end

  test "#entries" do |data|
    assert_equal data[:entries], SequenceSet.new(data[:input]).entries
  end

  test "#each_entry" do |data|
    seqset = SequenceSet.new(data[:input])
    array = []
    assert_equal seqset, seqset.each_entry { array << _1 }
    assert_equal data[:entries], array
    assert_equal data[:entries], seqset.each_entry.to_a
  end

  test "#ranges" do |data|
    assert_equal data[:ranges], SequenceSet.new(data[:input]).ranges
  end

  test "#string" do |data|
    set = SequenceSet.new(data[:input])
    str = data[:to_s]
    str = nil if str.empty?
    assert_equal str, set.string
  end

  test "#normalized_string" do |data|
    set = SequenceSet.new(data[:input])
    assert_equal data[:normalize], set.normalized_string
  end

  test "#normalize" do |data|
    set = SequenceSet.new(data[:input])
    assert_equal data[:normalize], set.normalize.string
    if data[:input]
    end
  end

  test "#normalize!" do |data|
    set = SequenceSet.new(data[:input])
    set.normalize!
    assert_equal data[:normalize], set.string
  end

  test "#to_s" do |data|
    assert_equal data[:to_s], SequenceSet.new(data[:input]).to_s
  end

  test "#count" do |data|
    assert_equal data[:count], SequenceSet.new(data[:input]).count
  end

  test "#valid_string" do |data|
    if (expected = data[:to_s]).empty?
      assert_raise DataFormatError do
        SequenceSet.new(data[:input]).valid_string
      end
    else
      assert_equal data[:to_s], SequenceSet.new(data[:input]).valid_string
    end
  end

  test "#~ and #complement" do |data|
    set = SequenceSet.new(data[:input])
    assert_equal(data[:complement], set.complement.to_s)
    assert_equal(data[:complement], (~set).to_s)
  end

  test "#numbers" do |data|
    expected = data[:numbers]
    if expected.is_a?(Class) && expected < Exception
      assert_raise expected do SequenceSet.new(data[:input]).numbers end
    else
      assert_equal expected, SequenceSet.new(data[:input]).numbers
    end
  end

  test "SequenceSet[input]" do |input|
    case (input = data[:input])
    when nil
      assert_raise DataFormatError do SequenceSet[input] end
    when String
      seqset = SequenceSet[input]
      assert_equal data[:input], seqset.to_s
      assert_equal data[:normalize], seqset.normalized_string
      assert seqset.frozen?
    else
      seqset = SequenceSet[input]
      assert_equal data[:normalize], seqset.to_s
      assert seqset.frozen?
    end
  end

  test "set == ~~set" do |data|
    set = SequenceSet.new(data[:input])
    assert_equal set, set.complement.complement
    assert_equal set, ~~set
  end

  test "set | ~set == full" do |data|
    set = SequenceSet.new(data[:input])
    assert_equal SequenceSet.new("1:*"), set + set.complement
  end

end
