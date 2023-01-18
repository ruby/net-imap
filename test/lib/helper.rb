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
require "test/unit"
require "core_assertions"

Test::Unit::TestCase.include Test::Unit::CoreAssertions
