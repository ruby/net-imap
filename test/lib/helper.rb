unless ENV["SIMPLECOV_DISABLE"] in /\A(1|y(es)?|t(rue)?)\z/i
  require "simplecov"

  # Cannot use ".simplecov" file: simplecov-json triggers a circular require.
  require "simplecov-json"
  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter,
  ])

  SimpleCov.start do
    command_name "Net::IMAP tests"
    enable_coverage  :branch
    primary_coverage :branch
    enable_coverage_for_eval

    add_filter "/test/"
    add_filter "/rakelib/"

    add_group "Parser", %w[lib/net/imap/response_parser.rb
                          lib/net/imap/response_parser]
    add_group "Config", %w[lib/net/imap/config.rb
                          lib/net/imap/config]
    add_group "SASL", %w[lib/net/imap/sasl.rb
                        lib/net/imap/sasl
                        lib/net/imap/authenticators.rb]
    add_group "StringPrep", %w[lib/net/imap/stringprep.rb
                              lib/net/imap/stringprep]
  end
end

require "test/unit"
require "core_assertions"

Test::Unit::TestCase.include Test::Unit::CoreAssertions

require "net/imap"
class Net::IMAP::TestCase < Test::Unit::TestCase
  def setup
    Net::IMAP.config.reset
    @do_not_reverse_lookup = Socket.do_not_reverse_lookup
    Socket.do_not_reverse_lookup = true
    @threads = []
  end

  def teardown
    assert_join_threads(@threads) unless @threads.empty?
  ensure
    Socket.do_not_reverse_lookup = @do_not_reverse_lookup
  end

  def wait_for_response_count(imap, type:, count:,
                              timeout: 0.5, interval: 0.001)
    deadline = Time.now + timeout
    loop do
      current_count = imap.responses(type, &:size)
      break :count    if count <= current_count
      break :deadline if deadline < Time.now
      sleep interval
    end
  end

  # Copied from minitest
  def assert_pattern
    flunk "assert_pattern requires a block to capture errors." unless block_given?
    assert_block do
      yield
      true
    rescue NoMatchingPatternError => e
      flunk e.message
    end
  end

end

require_relative "profiling_helper"
