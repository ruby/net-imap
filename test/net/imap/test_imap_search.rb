# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPSearchTest < Net::IMAP::TestCase
  include Net::IMAP::FakeServer::TestHelper

  test("#search/#uid_search") do
    with_fake_server do |server, imap|
      search_result = Net::IMAP::SearchResult[
        1, 2, 3, 5, 8, 13, 21, 34, 55, modseq: 1234
      ]
      search_resp = ->cmd do
        cmd.puts search_result.to_s("SEARCH")
        cmd.done_ok
      end

      server.on "SEARCH", &search_resp
      assert_equal search_result, imap.search(["subject", "hello world",
                                               [1..5, 8, 10..-1]])
      cmd = server.commands.pop
      assert_equal(
        ["SEARCH",'subject "hello world" 1:5,8,10:*'],
        [cmd.name, cmd.args]
      )

      imap.search(["OR", 1..1000, -1, "UID", 12345..-1])
      assert_equal "OR 1:1000 * UID 12345:*", server.commands.pop.args

      imap.search([1..1000, "UID", 12345..])
      assert_equal "1:1000 UID 12345:*", server.commands.pop.args

      # Unfortunately, we can't send every sequence-set string directly
      imap.search(["SUBJECT", "1,*"])
      assert_equal 'SUBJECT "1,*"', server.commands.pop.args

      imap.search(["subject", "hello", Set[1, 2, 3, 4, 5, 8, *(10..100)]])
      assert_equal "subject hello 1:5,8,10:100", server.commands.pop.args

      imap.search('SUBJECT "Hello world"', "UTF-8")
      assert_equal 'CHARSET UTF-8 SUBJECT "Hello world"', server.commands.pop.args

      imap.search('CHARSET UTF-8 SUBJECT "Hello world"')
      assert_equal 'CHARSET UTF-8 SUBJECT "Hello world"', server.commands.pop.args

      imap.search('SUBJECT "Hello world"', charset: "UTF-8")
      assert_equal 'CHARSET UTF-8 SUBJECT "Hello world"', server.commands.pop.args

      imap.search([:*])
      assert_equal "*", server.commands.pop.args

      seqset_coercible = Object.new
      def seqset_coercible.to_sequence_set
        Net::IMAP::SequenceSet[1..9]
      end
      imap.search([seqset_coercible])
      assert_equal "1:9", server.commands.pop.args

      server.on "UID SEARCH", &search_resp
      assert_equal search_result, imap.uid_search(["subject", "hello",
                                                   [1..22, 30..-1]])
      cmd = server.commands.pop
      assert_equal ["UID SEARCH", "subject hello 1:22,30:*"], [cmd.name, cmd.args]

      assert_equal search_result, imap.search(
        "RETURN (COUNT) NOT (FLAGGED (OR SEEN ANSWERED))"
      )
      cmd = server.commands.pop
      assert_equal "RETURN (COUNT) NOT (FLAGGED (OR SEEN ANSWERED))", cmd.args

      assert_equal search_result, imap.search([
        "RETURN", %w(MIN MAX COUNT), "NOT", ["FLAGGED", %w(OR SEEN ANSWERED)]
      ])
      cmd = server.commands.pop
      assert_equal "RETURN (MIN MAX COUNT) NOT (FLAGGED (OR SEEN ANSWERED))", cmd.args

      assert_equal search_result, imap.search(
        ["NOT", ["FLAGGED", %w(OR SEEN ANSWERED)]], return: %w(MIN MAX COUNT)
      )
      cmd = server.commands.pop
      assert_equal "RETURN (MIN MAX COUNT) NOT (FLAGGED (OR SEEN ANSWERED))", cmd.args

      assert_equal search_result, imap.search(
        ["UID", 1234..], return: %w(PARTIAL -500:-1)
      )
      cmd = server.commands.pop
      assert_equal "RETURN (PARTIAL -500:-1) UID 1234:*", cmd.args

      assert_equal search_result, imap.search(
        ["UID", 1234..], return: [:PARTIAL, "-500:-1"]
      )
      cmd = server.commands.pop
      assert_equal "RETURN (PARTIAL -500:-1) UID 1234:*", cmd.args

      assert_equal search_result, imap.search(
        ["UID", 1234..], return: [:PARTIAL, -500..-1, :FOO, 1..]
      )
      cmd = server.commands.pop
      assert_equal "RETURN (PARTIAL -500:-1 FOO 1:*) UID 1234:*", cmd.args
    end
  end

  test("#search/#uid_search with invalid arguments") do
    with_fake_server do |server, imap|
      server.on "SEARCH"     do |cmd| cmd.fail_no "should fail before this" end
      server.on "UID SEARCH" do |cmd| cmd.fail_no "should fail before this" end

      assert_raise(ArgumentError) do
        imap.search(["charset", "foo", "ALL"], "bar")
      end
      assert_raise(ArgumentError) do
        imap.search("charset foo ALL", "bar")
      end
      assert_raise(ArgumentError) do
        imap.search(["ALL"], "foo", charset: "bar")
      end
      assert_raise(ArgumentError) do
        imap.search(["charset", "foo", "ALL"], charset: "bar")
      end
      assert_raise(ArgumentError) do
        imap.search("charset foo ALL", charset: "bar")
      end
      # Parsing return opts is too complicated, for now.
      # assert_raise(ArgumentError) do
      #   imap.search("return () charset foo ALL", "bar")
      # end

      assert_raise(ArgumentError) do
        imap.search(["retURN", %w(foo bar), "ALL"], return: %w[foo bar])
      end
      assert_raise(ArgumentError) do
        imap.search("RETURN (foo bar) ALL", return: %w[foo bar])
      end
      assert_raise(TypeError) do
        imap.search("ALL", return: "foo bar")
      end
      assert_raise(TypeError) do
        imap.search(["retURN", "foo bar", "ALL"])
      end
    end
  end

  test("#search/#uid_search with ESEARCH or IMAP4rev2") do
    with_fake_server do |server, imap|
      # Example from RFC9051, 6.4.4:
      #   C: A282 SEARCH RETURN (MIN COUNT) FLAGGED
      #       SINCE 1-Feb-1994 NOT FROM "Smith"
      #   S: * ESEARCH (TAG "A282") MIN 2 COUNT 3
      #   S: A282 OK SEARCH completed
      server.on "SEARCH" do |cmd|
        cmd.untagged "ESEARCH", "(TAG \"unrelated1\") MIN 1 COUNT 2"
        cmd.untagged "ESEARCH", "(TAG %p) MIN 2 COUNT 3" % [cmd.tag]
        cmd.untagged "ESEARCH", "(TAG \"unrelated2\") MIN 222 COUNT 333"
        cmd.done_ok
      end
      result = imap.search(
        'RETURN (MIN COUNT) FLAGGED SINCE 1-Feb-1994 NOT FROM "Smith"'
      )
      cmd = server.commands.pop
      assert_equal Net::IMAP::ESearchResult.new(
        cmd.tag, false, [["MIN", 2], ["COUNT", 3]]
      ), result
      esearch_responses = imap.clear_responses("ESEARCH")
      assert_equal 2, esearch_responses.count
      refute esearch_responses.include?(result)
    end
  end

  test("missing server ESEARCH response") do
    with_fake_server do |server, imap|
      # Example from RFC9051, 6.4.4:
      #   C: A282 SEARCH RETURN (SAVE) FLAGGED SINCE 1-Feb-1994 NOT FROM "Smith"
      #   S: A282 OK SEARCH completed, result saved
      server.on "SEARCH"     do |cmd| cmd.done_ok "result saved" end
      server.on "UID SEARCH" do |cmd| cmd.done_ok "result saved" end
      result = imap.search(
        'RETURN (SAVE) FLAGGED SINCE 1-Feb-1994 NOT FROM "Smith"'
      )
      assert_pattern do
        result => Net::IMAP::ESearchResult[uid: false, tag: /^RUBY\d+/, data: []]
      end
      result = imap.uid_search(
        'RETURN (SAVE) FLAGGED SINCE 1-Feb-1994 NOT FROM "Smith"'
      )
      assert_pattern do
        result => Net::IMAP::ESearchResult[uid: true, tag: /^RUBY\d+/, data: []]
      end
    end
  end

  test("missing server SEARCH response") do
    with_fake_server do |server, imap|
      server.on "SEARCH",     &:done_ok
      server.on "UID SEARCH", &:done_ok
      found = imap.search ["subject", "hello"]
      assert_instance_of Net::IMAP::SearchResult, found
      assert_empty found
      found = imap.uid_search ["subject", "hello"]
      assert_instance_of Net::IMAP::SearchResult, found
      assert_empty found
    end
  end

  test("missing server SORT response") do
    with_fake_server do |server, imap|
      server.on "SORT",       &:done_ok
      server.on "UID SORT",   &:done_ok
      found = imap.sort ["INTERNALDATE"], ["subject", "hello"], "UTF-8"
      assert_equal [], found
      found = imap.uid_sort ["INTERNALDATE"], ["subject", "hello"], "UTF-8"
      assert_equal [], found
    end
  end

  test("missing server THREAD response") do
    with_fake_server do |server, imap|
      server.on "THREAD",     &:done_ok
      server.on "UID THREAD", &:done_ok
      found = imap.thread "REFERENCES", ["subject", "hello"], "UTF-8"
      assert_equal [], found
      found = imap.uid_thread "REFERENCES", ["subject", "hello"], "UTF-8"
      assert_equal [], found
    end
  end

end
