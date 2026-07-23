# frozen_string_literal: true

SimpleCov.configure do
  formatter SimpleCov::Formatter::HTMLFormatter

  enable_coverage  :branch
  enable_coverage  :eval

  skip "/test/"
  skip "/rakelib/"
  cover "lib/**/*.rb"

  group "Parser",     %w[lib/net/imap/response_parser.rb
                         lib/net/imap/response_parser]
  group "Config",     %w[lib/net/imap/config.rb
                         lib/net/imap/config]
  group "SASL",       %w[lib/net/imap/sasl.rb
                         lib/net/imap/sasl
                         lib/net/imap/authenticators.rb]
  group "StringPrep", %w[lib/net/imap/stringprep.rb
                         lib/net/imap/stringprep]
end
