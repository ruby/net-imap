# frozen_string_literal: true

require "net/imap"
require "test/unit"

class ESearchResultTest < Test::Unit::TestCase
  ESearchResult = Net::IMAP::ESearchResult
  SequenceSet   = Net::IMAP::SequenceSet

  test "#to_a" do
    esearch = ESearchResult.new(nil, true, [])
    assert_equal [], esearch.to_a
    esearch = ESearchResult.new(nil, false, [])
    assert_equal [], esearch.to_a
    esearch = ESearchResult.new(nil, false, [["ALL", SequenceSet["1,5:8"]]])
    assert_equal [1, 5, 6, 7, 8], esearch.to_a
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

  test "#relevancy returns RELEVANCY value (RFC6203: SEARCH=FUZZY)" do
    esearch = ESearchResult.new("A0007", true, [["RELEVANCY", [1, 99]]])
    assert_equal [1, 99], esearch.relevancy
    esearch = ESearchResult.new("A0008", true, [["RELEVANCY", [3, 12, 23]]])
    assert_equal [3, 12, 23], esearch.relevancy
  end

  test "#updates returns both ADDTO and REMOVEFROM values (RFC5267: CONTEXT)" do
    parser = Net::IMAP::ResponseParser.new
    expected = [
      ESearchResult::AddToContext.new(1, SequenceSet[2733]),
      ESearchResult::RemoveFromContext.new(1, SequenceSet[2732]),
      ESearchResult::AddToContext.new(1, SequenceSet[2731]),
    ]
    assert_equal expected, parser.parse(
      "* ESEARCH (TAG \"C01\") UID ADDTO (1 2733) REMOVEFROM (1 2732) ADDTO (1 2731)\r\n"
    ).data.updates
  end

end
