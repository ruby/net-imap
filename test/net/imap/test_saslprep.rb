# frozen_string_literal: true

require "net/imap"
require "test/unit"

class SASLprepTest < Test::Unit::TestCase
  include Net::IMAP::SASL

  # Test cases from RFC-4013 §3:
  #
  # #  Input            Output     Comments
  # -  -----            ------     --------
  # 1  I<U+00AD>X       IX         SOFT HYPHEN mapped to nothing
  # 2  user             user       no transformation
  # 3  USER             USER       case preserved, will not match #2
  # 4  <U+00AA>         a          output is NFKC, input in ISO 8859-1
  # 5  <U+2168>         IX         output is NFKC, will match #1
  def test_saslprep_valid_inputs
    {
      "I\u00ADX" => "IX",   # SOFT HYPHEN mapped to nothing
      "user"     => "user", # no transformation
      "USER"     => "USER", # case preserved, will not match #2
      "\u00aa"   => "a",    # output is NFKC, input in ISO 8859-1
      "\u2168"   => "IX",   # output is NFKC, will match #1
      # some more tests:
      "foo\u00a0bar" => "foo bar", # map to space
      "foo\u2000bar" => "foo bar", # map to space
      "foo\u3000bar" => "foo bar", # map to space
      "\u0627"       => "\u0627",  # single RandALCat char is okay
      "\u{1f468}\u200d\u{1f469}\u200d\u{1f467}" =>
        "\u{1f468}\u{1f469}\u{1f467}" # map ZWJ to nothing
    }.each do |input, output|
      assert_equal output, Net::IMAP.saslprep(input)
    end
  end

  # Test cases from RFC-4013 §3:
  #
  # #  Input            Output     Comments
  # -  -----            ------     --------
  # 6  <U+0007>                    Error - prohibited character
  # 7  <U+0627><U+0031>            Error - bidirectional check
  def test_saslprep_invalid_inputs
    {
      # from the RFC examples table
      "\u0007"       => [ProhibitedCodepoint, /ASCII control character/],
      "\u0627\u0031" => [BidiStringError,     /must start.*end with RandAL/],
      # some more prohibited codepoints
      "\x7f"         => [ProhibitedCodepoint, /ASCII control character/i],
      "\ufff9"       => [ProhibitedCodepoint, /Non-ASCII control character/i],
      "\ue000"       => [ProhibitedCodepoint, /private use.*C.3/i],
      "\u{f0000}"    => [ProhibitedCodepoint, /private use.*C.3/i],
      "\u{100000}"   => [ProhibitedCodepoint, /private use.*C.3/i],
      "\ufffe"       => [ProhibitedCodepoint, /Non-character code point.*C.4/i],
      "\xed\xa0\x80" => [StringPrepError,     /invalid byte seq\w+ in UTF-8/i],
      "\ufffd"       => [ProhibitedCodepoint, /inapprop.* plain text.*C.6/i],
      "\u2FFb"       => [ProhibitedCodepoint, /inapprop.* canonical rep.*C.7/i],
      "\u202c"       => [ProhibitedCodepoint, /change display.*deprecate.*C.8/i],
      "\u{e0001}"    => [ProhibitedCodepoint, /tagging character/i],
      # some more invalid bidirectional characters
      "\u0627abc\u0627" => [BidiStringError,  /must not contain.* Lcat/i],
      "\u0627123"       => [BidiStringError,  /must start.*end with RandAL/i],
    }.each do |input, (err, msg)|
      assert_nil Net::IMAP.saslprep input
      assert_raise_with_message err, msg do
        Net::IMAP.saslprep(input, exception: true)
      end
    end
  end

end
