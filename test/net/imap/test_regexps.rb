# frozen_string_literal: true

require "net/imap"
require "test/unit"

return unless Regexp.respond_to?(:linear_time?)

begin
  require_relative "regexp_collector"
rescue LoadError
  warn "Can't collect regexps to test Regexp.linear_time?(...)"
end

unless defined?(RegexpCollector)
  class RegexpCollector # :nodoc:
    def initialize(...) end
    def to_a; [] end
    def to_h; {} end
  end
end

class IMAPRegexpsTest < Test::Unit::TestCase

  data(
    RegexpCollector.new(
      Net::IMAP,
      exclude_map: {
        Net::IMAP => %i[BodyTypeAttachment BodyTypeExtension], # deprecated
      },
      exclude: [
        /\n(?!\z)/n, # TODO (in Net::IMAP#put_string)
        Net::IMAP::StringPrep::Tables::BIDI_FAILS_REQ2, # TODO
        Net::IMAP::StringPrep::Tables::BIDI_FAILS_REQ3, # TODO
        # The following regexps are built using BIDI_FAILS_REQ{2,3}
        Net::IMAP::StringPrep::Tables::BIDI_FAILURE,
        Net::IMAP::StringPrep::SASLprep::PROHIBITED,
        Net::IMAP::StringPrep::SASLprep::PROHIBITED_STORED,
      ]
    ).to_h
  )

  def test_linear_time(data)
    assert Regexp.linear_time?(data.regexp)
  end

end
