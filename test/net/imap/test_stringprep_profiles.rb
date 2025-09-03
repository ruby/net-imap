# frozen_string_literal: true

require "net/imap"
require "test/unit"

class StringPrepProfilesTest < Net::IMAP::TestCase
  include Net::IMAP::StringPrep
  include Net::IMAP::StringPrep::Trace

  def test_trace_profile_prohibit_ctrl_chars
    assert_raise(ProhibitedCodepoint) {
      stringprep_trace("no\ncontrol\rchars")
    }
  end

  def test_trace_profile_prohibit_tagging_chars
    assert_raise(ProhibitedCodepoint) {
      stringprep_trace("regional flags use tagging chars: e.g." \
                       "🏴󠁧󠁢󠁥󠁮󠁧󠁿 England, " \
                       "🏴󠁧󠁢󠁳󠁣󠁴󠁿 Scotland, " \
                       "🏴󠁧󠁢󠁷󠁬󠁳󠁿 Wales.")
    }
  end

end
