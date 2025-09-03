# frozen_string_literal: true

require "net/imap"
require "test/unit"

class ESearchResultTest < Net::IMAP::TestCase
  ESearchResult = Net::IMAP::ESearchResult
  SequenceSet   = Net::IMAP::SequenceSet
  ExtensionData = Net::IMAP::ExtensionData

  test "#to_sequence_set" do
    esearch = ESearchResult.new(nil, true, [])
    assert_equal SequenceSet.empty, esearch.to_sequence_set
    esearch = ESearchResult.new(nil, false, [])
    assert_equal SequenceSet.empty, esearch.to_sequence_set
    esearch = ESearchResult.new(nil, false, [["ALL", SequenceSet["1,5:8"]]])
    assert_equal SequenceSet[1, 5, 6, 7, 8], esearch.to_sequence_set
    esearch = ESearchResult.new(nil, false, [
      ["PARTIAL", ESearchResult::PartialResult[1..5, "1,5:8"]]
    ])
    assert_equal SequenceSet[1, 5, 6, 7, 8], esearch.to_sequence_set
  end

  test "#to_a" do
    esearch = ESearchResult.new(nil, true, [])
    assert_equal [], esearch.to_a
    esearch = ESearchResult.new(nil, false, [])
    assert_equal [], esearch.to_a
    esearch = ESearchResult.new(nil, false, [["ALL", SequenceSet["1,5:8"]]])
    assert_equal [1, 5, 6, 7, 8], esearch.to_a
    esearch = ESearchResult.new(nil, false, [
      ["PARTIAL", ESearchResult::PartialResult[1..5, "1,5:8"]]
    ])
    assert_equal [1, 5, 6, 7, 8], esearch.to_a
  end

  test "#each" do
    esearch = ESearchResult.new(nil, true, [])
    assert_kind_of Enumerator, esearch.each
    ary = []
    assert_same esearch, esearch.each { ary << _1 }
    assert_equal [], ary

    esearch = ESearchResult.new(nil, false, [["ALL", SequenceSet["1,5:8"]]])
    assert_equal [1, 5, 6, 7, 8], esearch.each.to_a
    ary = []
    assert_same esearch, esearch.each { ary << _1 }
    assert_equal [1, 5, 6, 7, 8], ary

    esearch = ESearchResult.new(nil, false, [
      ["PARTIAL", ESearchResult::PartialResult[1..5, "1,5:8"]]
    ])
    assert_equal [1, 5, 6, 7, 8], esearch.each.to_a
    ary = []
    assert_same esearch, esearch.each { ary << _1 }
    assert_equal [1, 5, 6, 7, 8], ary
  end

  test "#tag" do
    esearch = ESearchResult.new("A0001", false, [["count", 0]])
    assert_equal "A0001", esearch.tag
    esearch = ESearchResult.new("A0002", false, [["count", 0]])
    assert_equal "A0002", esearch.tag
  end

  test "#uid" do
    esearch = ESearchResult.new("A0003", true, [["count", 0]])
    assert_equal true, esearch.uid
    assert_equal true, esearch.uid?
    esearch = ESearchResult.new("A0004", false, [["count", 0]])
    assert_equal false, esearch.uid
    assert_equal false, esearch.uid?
  end

  test "#data.assoc('UNKNOWN') returns ExtensionData value" do
    result = Net::IMAP::ResponseParser.new.parse(
      "* ESEARCH (TAG \"A0006\") UID UNKNOWN 1\r\n"
    ).data
    result => ESearchResult[data:]
    assert_equal(["UNKNOWN", ExtensionData[1]],
                 data.assoc("UNKNOWN"))
    result = Net::IMAP::ResponseParser.new.parse(
      "* ESEARCH (TAG \"A0006\") UID UNKNOWN 1:2\r\n"
    ).data
    result => ESearchResult[data:]
    assert_equal(["UNKNOWN", ExtensionData[SequenceSet[1..2]]],
                 data.assoc("UNKNOWN"))
    result = Net::IMAP::ResponseParser.new.parse(
      "* ESEARCH (TAG \"A0006\") UID UNKNOWN (-1:-100 200:250,252:300)\r\n"
    ).data
    result => ESearchResult[data:]
    assert_equal(
      [
        "UNKNOWN",
        ExtensionData.new(["-1:-100", "200:250,252:300"]),
      ],
      data.assoc("UNKNOWN")
    )
  end

  # "simple" result da¨a return exactly what is in the data.assoc
  test "simple RFC4731 and RFC9051 return data accessors" do
    seqset  = SequenceSet["5:9,101:105,151:152"]
    esearch = ESearchResult.new(
      "A0005",
      true,
      [
        ["MIN",        5],
        ["MAX",      152],
        ["COUNT",     12],
        ["ALL",   seqset],
        ["MODSEQ", 12345],
      ]
    )
    assert_equal      5, esearch.min
    assert_equal    152, esearch.max
    assert_equal     12, esearch.count
    assert_equal seqset, esearch.all
    assert_equal  12345, esearch.modseq
  end

  test "#partial returns PARTIAL value (RFC9394: PARTIAL)" do
    result = Net::IMAP::ResponseParser.new.parse(
      "* ESEARCH (TAG \"A0006\") UID PARTIAL (-1:-100 200:250,252:300)\r\n"
    ).data
    assert_equal(ESearchResult, result.class)
    assert_equal(
      ESearchResult::PartialResult.new(
        -100..-1, SequenceSet[200..250, 252..300]
      ),
      result.partial
    )
  end

end
