# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rake/clean"

Rake::TestTask.new(:test) do |t|
  t.libs << "test/lib"
  t.ruby_opts << "-rhelper"
  t.test_files = FileList["test/**/test_*.rb"]
end

task :default => :test

desc "Output HTML coverage data report, and error when threshholds aren't met"
task "test:coverage:report" do
  require "simplecov"

  SimpleCov.collate "coverage/.resultset.json" do
    formatter SimpleCov::Formatter::HTMLFormatter

    coverage(:line) do
      minimum  95

      minimum  98, per: group("Config")
      minimum  97, per: group("StringPrep")
      minimum  97, per: group("SASL")
      minimum  95, per: group("Data Types")
      minimum  94, per: group("Parser")
      minimum  92, per: group("Client")

      minimum  80, per: :file
      minimum  55, per: "lib/net/imap/search_result.rb"
    end

    # NOTE: branch coverage varies more widely between ruby versions
    coverage(:branch) do
      # eval branch coverage varies too much between runtime environments
      ignore :eval_generated

      minimum  80

      minimum  90, per: group("Data Types")
      minimum  85, per: group("Config")
      minimum  80, per: group("Client")
      minimum  80, per: group("Parser")
      minimum  70, per: group("SASL")
      minimum  70, per: group("StringPrep")

      minimum  60, per: :file
      minimum  50, per: "lib/net/imap/sasl/authenticators.rb"
      minimum  50, per: "lib/net/imap/config/attr_accessors.rb"
    end

    coverage(:method) do
      minimum  88

      minimum 100, per: group("Config")
      minimum  90, per: group("Data Types")
      minimum  90, per: group("StringPrep")
      minimum  85, per: group("Client")
      minimum  80, per: group("Parser")
      minimum  80, per: group("SASL")

      minimum  65, per: :file
      minimum  60, per: "lib/net/imap/response_parser/parser_utils.rb"
      minimum  55, per: "lib/net/imap/sasl/authenticators.rb"
      minimum  50, per: "lib/net/imap/authenticators.rb"
      minimum  50, per: "lib/net/imap/sasl/anonymous_authenticator.rb"
      minimum  35, per: "lib/net/imap/sasl/protocol_adapters.rb"
      minimum  20, per: "lib/net/imap/response_data.rb"
    end
  end
end
