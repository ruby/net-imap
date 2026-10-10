# frozen_string_literal: true

SimpleCov.configure do
  enable_coverage  :branch
  enable_coverage  :method
  enable_coverage  :eval

  skip "/test/"
  skip "/rakelib/"
  cover "lib/**/*.rb"

  group "Parser",     %w[lib/net/imap/response_parser.rb
                         lib/net/imap/response_parser]

  group "Client",     %w[lib/net/imap.rb
                         lib/net/imap/connection_state.rb
                         lib/net/imap/deprecated_client_options.rb
                         lib/net/imap/errors.rb
                         lib/net/imap/response_reader.rb]

  group "Config",     %w[lib/net/imap/config.rb
                         lib/net/imap/config]

  group "Data Types", %w[lib/net/imap/flags.rb
                         lib/net/imap/sequence_set.rb] +
                         [%r{lib/net/imap/\w*_data\.rb},
                          %r{lib/net/imap/\w*_result.rb},
                          %r{lib/net/imap/data_\w+\.rb}]

  group "SASL",       %w[lib/net/imap/sasl.rb
                         lib/net/imap/sasl
                         lib/net/imap/sasl_adapter.rb
                         lib/net/imap/authenticators.rb]

  group "StringPrep", %w[lib/net/imap/stringprep.rb
                         lib/net/imap/stringprep]
end
