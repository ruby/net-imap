# frozen_string_literal: true

require "net/imap"
require "test/unit"

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

class IMAPRegexpsTest < Net::IMAP::TestCase

  data(
    RegexpCollector.new(
      Net::IMAP,
      exclude_map: {
        Net::IMAP => %i[
          PlainAuthenticator
          XOauth2Authenticator
        ], # deprecated
        Net::IMAP::StringPrep::SASLprep => %i[
          UNASSIGNED
        ],
        Net::IMAP::SASL => %i[
          StringPrepError
          ProhibitedCodepoint
          BidiStringError
          StringPrep
        ], # deprecated
      },
    ).to_h
  )

  def test_linear_time(data)
    regexp = data.regexp
    assert Regexp.linear_time?(regexp), "%p might backtrack" % [regexp]
  rescue NoMethodError
    pend "Regexp.linear_time? not implemented by #{RUBY_ENGINE} #{RUBY_ENGINE_VERSION}"
  rescue Test::Unit::AssertionFailedError
    raise if RUBY_ENGINE == "ruby"
    pend "%p might backtrack in %s %s" % [regexp, RUBY_ENGINE, RUBY_ENGINE_VERSION]
  end

end
