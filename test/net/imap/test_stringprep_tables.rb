# frozen_string_literal: true

require "net/imap"
require "test/unit"
require "json"

require_relative "../../../rakelib/string_prep_tables_generator"

class StringPrepTablesTest < Net::IMAP::TestCase
  include Net::IMAP::StringPrep

  # Surrogates are excluded.  They are handled by enforcing valid UTF8 encoding.
  VALID_CODEPOINTS = (0..0x10_ffff).map{|cp| cp.chr("UTF-8") rescue nil}.compact

  rfc3454_transformer = StringPrepTablesGenerator.new.transformer

  # testing with set inclusion, just in case the regexp generation is buggy
  RFC3454_TABLE_SETS = rfc3454_transformer.sets

  # The library regexps are a mixture of generated vs handcrafted, in order to
  # reduce load-time and memory footprint of the largest tables.
  #
  # These are the simple generated regexps, which directly translate each table
  # into a character class with every codepoint.  These can be used to verify
  # the hand-crafted regexps are correct, for every supported version of ruby.
  RFC3454_TABLE_REGEXPS = rfc3454_transformer.regexps

  # C.5 (surrogates) aren't really tested here.
  # D.2 includes surrogates... which also aren't tested here.
  #
  # This is ok: valid UTF-8 encoding is enforced and cannot contain surrogates.

  def test_rfc3454_table_A_1;   assert_rfc3454_table_compliance "A.1"   end
  def test_rfc3454_table_B_1;   assert_rfc3454_table_compliance "B.1"   end
  def test_rfc3454_table_B_2;   assert_rfc3454_table_compliance "B.2"   end
  def test_rfc3454_table_C_1_1; assert_rfc3454_table_compliance "C.1.1" end
  def test_rfc3454_table_C_1_2; assert_rfc3454_table_compliance "C.1.2" end
  def test_rfc3454_table_C_2_1; assert_rfc3454_table_compliance "C.2.1" end
  def test_rfc3454_table_C_2_2; assert_rfc3454_table_compliance "C.2.2" end
  def test_rfc3454_table_C_3;   assert_rfc3454_table_compliance "C.3"   end
  def test_rfc3454_table_C_4;   assert_rfc3454_table_compliance "C.4"   end
  def test_rfc3454_table_C_5;   assert_rfc3454_table_compliance "C.5"   end
  def test_rfc3454_table_C_6;   assert_rfc3454_table_compliance "C.6"   end
  def test_rfc3454_table_C_7;   assert_rfc3454_table_compliance "C.7"   end
  def test_rfc3454_table_C_8;   assert_rfc3454_table_compliance "C.8"   end
  def test_rfc3454_table_C_9;   assert_rfc3454_table_compliance "C.9"   end
  def test_rfc3454_table_D_1;   assert_rfc3454_table_compliance "D.1"   end
  def test_rfc3454_table_D_2;   assert_rfc3454_table_compliance "D.2"   end

  def assert_rfc3454_table_compliance(name)
    set     = RFC3454_TABLE_SETS   .fetch(name)
    regexp  = RFC3454_TABLE_REGEXPS.fetch(name)
    coded   = Tables::REGEXPS      .fetch(name)
    matched_set = VALID_CODEPOINTS
      .map{|cp| cp.unpack1 "U"}
      .grep(set)
      .map{|cp| [cp].pack "U"}
    matched_reg = VALID_CODEPOINTS.grep(regexp)
    matched_lib = VALID_CODEPOINTS.grep(coded)
    assert_not_empty matched_lib unless name == "C.5"
    # assert_equal freezes up on errors; too much data to pretty print.
    # and printing out weird unicode control characters (etc) isn't very useful.
    if matched_lib != matched_reg
      missing = (matched_reg - matched_lib).map{|s|"%04x" % s.codepoints.first}
      extra   = (matched_lib - matched_reg).map{|s|"%04x" % s.codepoints.first}
      assert_empty missing.first(100), "missing some codepoints"
      assert_empty extra.first(100),   "some extra codepoints"
    else
      assert_equal matched_lib, matched_reg
      assert_equal matched_lib, matched_set
    end
  end

end
