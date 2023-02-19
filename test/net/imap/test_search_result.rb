# frozen_string_literal: true

require "net/imap"
require "test/unit"

class SearchDataTests < Test::Unit::TestCase
  SearchResult = Net::IMAP::SearchResult

  test "#frozen?" do
    assert SearchResult.new([1, 3, 5]).frozen?
    assert SearchResult[1, 3, 5].frozen?
    assert SearchResult[1, 3, 5, modseq: 9].frozen?
    assert SearchResult[1, 3, 5, modseq: 9].clone.frozen?
    assert SearchResult[1, 3, 5, modseq: 9].dup.dup.frozen?
  end

  test "#modseq" do
    assert_nil SearchResult[12, 34].modseq
    assert_equal 123_456_789, SearchResult[12, 34, modseq: 123_456_789].modseq
  end

  test "#== ignores the order of elements" do
    unsorted = SearchResult[4, 2, 2048, 99]
    sorted   = SearchResult[2, 4, 99, 2048]
    array    = [2, 4, 99, 2048]
    assert_equal sorted, array
    assert_equal unsorted, array
  end

  test "#== checks modseq" do
    unsorted = SearchResult[4, 2, 2048, 99, modseq: 99_999]
    sorted   = SearchResult[2, 4, 99, 2048, modseq: 99_999]
    assert_equal unsorted, sorted
    assert_equal sorted, unsorted
  end

  test "SearchResult[*nz_numbers] == Array[*nz_numbers]" do
    array  = [1, 5, 20, 3, 98]
    result = SearchResult[*array]
    assert_equal array, result
    assert_equal result, array
  end

  test "SearchResult.new(nz_numbers) == Array.new(nz_numbers)" do
    nz_numbers = [11, 35, 39, 1083, 958]
    result = SearchResult.new(nz_numbers)
    array  = Array.new(nz_numbers)
    assert_equal array, result
    assert_equal result, array
  end

  test "SearchResult[*nz_numbers, modseq: nz_number] != Array[*nz_numbers]" do
    array  = [1, 5, 20, 3, 98]
    result = SearchResult[*array, modseq: 123456]
    refute_equal result, array
  end

  test "Array[*nz_numbers] == SearchResult[*nz_numbers, modseq: nz_number]" do
    array  = [1, 5, 20, 3, 98]
    result = SearchResult[*array, modseq: 123456]
    assert_equal array, result
  end

  test "SearchResult[*nz_numbers] == Array[*differently_sorted]" do
    array  = [1, 5, 20, 3, 98]
    result = SearchResult[*array.reverse]
    assert_equal result, array
  end

  test "Array[*nz_numbers] != SearchResult[*differently_sorted]" do
    array  = [1, 5, 20, 3, 98]
    result = SearchResult[*array.reverse]
    refute_equal array, result
  end

  test "#inspect" do
    assert_equal "[1, 2, 3]", Net::IMAP::SearchResult[1, 2, 3].inspect
    assert_equal("Net::IMAP::SearchResult[1, 3, modseq: 9]",
                 Net::IMAP::SearchResult[1, 3, modseq: 9].inspect)
  end

  test "#to_s" do
    assert_equal "* SEARCH 1 2 3", Net::IMAP::SearchResult[1, 2, 3].to_s
    assert_equal("* SEARCH 3 2 1 (MODSEQ 9)",
                 Net::IMAP::SearchResult[3, 2, 1, modseq: 9].to_s)
  end

  test "#to_s(type)" do
    assert_equal "* SEARCH 1 3", Net::IMAP::SearchResult[1, 3].to_s("SEARCH")
    assert_equal "* SORT 1 2 3", Net::IMAP::SearchResult[1, 2, 3].to_s("SORT")
    assert_equal("* SORT 99 111 44 (MODSEQ 999)",
                 Net::IMAP::SearchResult[99, 111, 44, modseq: 999].to_s("SORT"))
    assert_equal("99 111 44 (MODSEQ 999)",
                 Net::IMAP::SearchResult[99, 111, 44, modseq: 999].to_s(nil))
  end
end
