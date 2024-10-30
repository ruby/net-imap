require "simplecov"

# Cannot use ".simplecov" file: simplecov-json triggers a circular require.
begin
  require "simplecov-json"
  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter,
  ])
rescue LoadError
  # for `make test-bundled-gems` in ruby-core repository.
  # That task does not install C extension gem like json.
end

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

class Test::Unit::TestCase
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
end
