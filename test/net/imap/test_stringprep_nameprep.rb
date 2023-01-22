# frozen_string_literal: true

require "net/imap"
require "test/unit"

class StringPrepNamePrepTest < Test::Unit::TestCase
  include Net::IMAP::StringPrep
  include Net::IMAP::StringPrep::NamePrep

  # The following test cases were taken from
  # https://www.gnu.org/software/libidn/draft-josefsson-idn-test-vectors.txt
  # ...mostly from Appendix A.

  # Hash[name, [in, out | exception, stored = false]
  NAMEPREP_TEST_VECTORS = {
    "Map to nothing" => [
      "foo\xC2\xAD\xCD\x8F\xE1\xA0\x86\xE1\xA0\x8B" \
      "bar\xE2\x80\x8B\xE2\x81\xA0" \
      "baz\xEF\xB8\x80\xEF\xB8\x88\xEF\xB8\x8F\xEF\xBB\xBF",
      "foobarbaz"
    ],
    "Case folding ASCII U+0043 U+0041 U+0046 U+0045" => [
      "CAFE", "cafe"
    ],
    "Case folding 8bit U+00DF (german sharp s)" => [
      "\xC3\x9F", "ss"
    ],
    "Case folding U+0130 (turkish capital I with dot)" => [
      "\xC4\xB0", "i\xcc\x87"
    ],
    "Case folding multibyte U+0143 U+037A" => [
      "\xC5\x83\xCD\xBA", "\xC5\x84 \xCE\xB9"
    ],
    "Case folding U+2121 U+33C6 U+1D7BB" => [
      "\xE2\x84\xA1\xE3\x8F\x86\xF0\x9D\x9E\xBB",
      "telc\xE2\x88\x95""kg\xCF\x83"
    ],
    "Normalization of U+006a U+030c U+00A0 U+00AA" => [
      "\x6A\xCC\x8C\xC2\xA0\xC2\xAA", "\xC7\xB0 a"
    ],
    "Case folding U+1FB7 and normalization" => [
      "\xE1\xBE\xB7", "\xE1\xBE\xB6\xCE\xB9"
    ],
    "Incorrect UTF-8 encoding of U+00DF" => [
      # n.b. this example isn't found in Appendix A, but is in §7.
      "\xC3\xdf", [ArgumentError, /invalid byte sequence in UTF-8/]
    ],
    "Incorrect UTF-8 encoding of U+01F0" => [
      # n.b. Appendix A doesn't indicate an error for this, but §7 does.
      "\xC7\xF0", [ArgumentError, /invalid byte sequence in UTF-8/]
    ],
    "Self-reverting case folding U+0390 and normalization" => [
      "\xCE\x90", "\xCE\x90"
    ],
    "Self-reverting case folding U+03B0 and normalization" => [
      "\xCE\xB0", "\xCE\xB0"
    ],
    "Self-reverting case folding U+1E96 and normalization" => [
      "\xE1\xBA\x96", "\xE1\xBA\x96"
    ],
    "Self-reverting case folding U+1F56 and normalization" => [
      "\xE1\xBD\x96", "\xE1\xBD\x96"
    ],
    "ASCII space character U+0020" => [
      "\x20", "\x20"
    ],
    "Non-ASCII 8bit space character U+00A0" => [
      "\xC2\xA0", "\x20"
    ],
    "Non-ASCII multibyte space character U+1680" => [
      "\xE1\x9A\x80", ProhibitedCodepoint
    ],
    "Non-ASCII multibyte space character U+2000" => [
      "\xE2\x80\x80", "\x20"
    ],
    "Zero Width Space U+200b" => [
      "\xE2\x80\x8b", ""
    ],
    "Non-ASCII multibyte space character U+3000" => [
      "\xE3\x80\x80", "\x20"
    ],
    "ASCII control characters U+0010 U+007F" => [
      "\x10\x7F", "\x10\x7F"
    ],
    "Non-ASCII 8bit control character U+0085" => [
      "\xC2\x85", ProhibitedCodepoint
    ],
    "Non-ASCII multibyte control character U+180E" => [
      "\xE1\xA0\x8E", ProhibitedCodepoint
    ],
    "Zero Width No-Break Space U+FEFF" => [
      "\xEF\xBB\xBF", ""
    ],
    "Non-ASCII control character U+1D175" => [
      "\xF0\x9D\x85\xB5", ProhibitedCodepoint
    ],
    "Plane 0 private use character U+F123" => [
      "\xEF\x84\xA3", ProhibitedCodepoint
    ],
    "Plane 15 private use character U+F1234" => [
      "\xF3\xB1\x88\xB4", ProhibitedCodepoint
    ],
    "Plane 16 private use character U+10F234" => [
      "\xF4\x8F\x88\xB4", ProhibitedCodepoint
    ],
    "Non-character code point U+8FFFE" => [
      "\xF2\x8F\xBF\xBE", ProhibitedCodepoint
    ],
    "Non-character code point U+10FFFF" => [
      "\xF4\x8F\xBF\xBF", ProhibitedCodepoint
    ],
    "Surrogate code U+DF42" => [
      "\xED\xBD\x82", [ArgumentError, /invalid byte sequence in UTF-8/]
    ],
    "Non-plain text character U+FFFD" => [
      "\xEF\xBF\xBD", ProhibitedCodepoint
    ],
    "Ideographic description character U+2FF5" => [
      "\xE2\xBF\xB5", ProhibitedCodepoint
    ],
    "Display property character U+0341" => [
      "\xCD\x81", "\xCC\x81"
    ],
    "Left-to-right mark U+200E" => [
      "\xE2\x80\x8E", ProhibitedCodepoint
    ],
    "Deprecated U+202A" => [
      "\xE2\x80\xAA", ProhibitedCodepoint
    ],
    "Language tagging character U+E0001" => [
      "\xF3\xA0\x80\x81", ProhibitedCodepoint
    ],
    "Language tagging character U+E0042" => [
      "\xF3\xA0\x81\x82", ProhibitedCodepoint
    ],
    "Bidi: RandALCat character U+05BE and LCat characters" => [
      "foo\xD6\xBE""bar",
      [BidiStringError, /string with RandALCat.* must not contain LCat/]
    ],
    "Bidi: RandALCat character U+FD50 and LCat characters" => [
      "foo\xEF\xB5\x90""bar",
      [BidiStringError, /string with RandALCat.* must not contain LCat/]
    ],
    "Bidi: RandALCat character U+FB38 and LCat characters" => [
      "foo\xEF\xB9\xB6""bar", "foo \xd9\x8e""bar"
    ],
    "Bidi: RandALCat without trailing RandALCat U+0627 U+0031" => [
      "\xD8\xA7\x31",
      [BidiStringError,
       /string with RandALCat.* must start and end with RandALCat/]
    ],
    "Bidi: RandALCat character U+0627 U+0031 U+0628" => [
      "\xD8\xA7\x31\xD8\xA8", "\xD8\xA7\x31\xD8\xA8"
    ],
    "Unassigned code point U+E0002" => [
      "\xF3\xA0\x80\x82",
      [ProhibitedCodepoint, /contains.* unassigned code points.*Unicode 3.2/i],
      true
    ],
    "Larger test (shrinking)" => [
      "X\xC2\xAD\xC3\x9F\xC4\xB0\xE2\x84\xA1\x6a\xcc\x8c\xc2\xa0\xc2" \
      "\xaa\xce\xb0\xe2\x80\x80",
      "xssi\xcc\x87tel\xc7\xb0 a\xce\xb0 ",
      "Nameprep"
    ],
    "Larger test (expanding)" => [
      "X\xC3\x9F\xe3\x8c\x96\xC4\xB0\xE2\x84\xA1\xE2\x92\x9F\xE3\x8c\x80",
      "xss\xe3\x82\xad\xe3\x83\xad\xe3\x83\xa1\xe3\x83\xbc\xe3\x83\x88" \
      "\xe3\x83\xabi\xcc\x87tel\x28d\x29\xe3\x82\xa2\xe3\x83\x91" \
      "\xe3\x83\xbc\xe3\x83\x88"
    ],
  }

  NAMEPREP_TEST_VECTORS.each do |comment, (input, output, stored)|
    stored ||= false
    ex, message = output
    case output
    when String
      test comment do
        assert_equal output, nameprep(input, stored: stored), comment
      end
    when Class
      if message # in Class => ex, (String | Regexp) => message
        test comment do
          assert_raise_with_message(ex, message, comment) {
            nameprep(input, stored: stored)
          }
        end
      else # in Class => ex
        test comment do
          assert_raise(ex, comment) { nameprep(input, stored: stored) }
        end
      end
    end
  end

end
