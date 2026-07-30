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
      minimum           95

      minimum_per_group 98, only: "Config"
      minimum_per_group 97, only: "StringPrep"
      minimum_per_group 97, only: "SASL"
      minimum_per_group 95, only: "Data Types"
      minimum_per_group 94, only: "Parser"
      minimum_per_group 92, only: "Client"

      minimum_per_file  80
      minimum_per_file  55, only: "lib/net/imap/search_result.rb"
    end

    # NOTE: branch coverage varies more widely between ruby versions
    coverage(:branch) do
      minimum           80

      minimum_per_group 90, only: "Data Types"
      minimum_per_group 85, only: "Config"
      minimum_per_group 80, only: "Client"
      minimum_per_group 80, only: "Parser"
      minimum_per_group 70, only: "SASL"
      minimum_per_group 70, only: "StringPrep"

      minimum_per_file  60
      minimum_per_file  50, only: "lib/net/imap/sasl/authenticators.rb"
      minimum_per_file  50, only: "lib/net/imap/config/attr_accessors.rb"
    end

    coverage(:method) do
      minimum            88

      minimum_per_group 100, only: "Config"
      minimum_per_group  90, only: "Data Types"
      minimum_per_group  90, only: "StringPrep"
      minimum_per_group  85, only: "Client"
      minimum_per_group  80, only: "Parser"
      minimum_per_group  80, only: "SASL"

      minimum_per_file   65
      minimum_per_file   60, only: "lib/net/imap/response_parser/parser_utils.rb"
      minimum_per_file   55, only: "lib/net/imap/sasl/authenticators.rb"
      minimum_per_file   50, only: "lib/net/imap/authenticators.rb"
      minimum_per_file   50, only: "lib/net/imap/sasl/anonymous_authenticator.rb"
      minimum_per_file   35, only: "lib/net/imap/sasl/protocol_adapters.rb"
      minimum_per_file   20, only: "lib/net/imap/response_data.rb"
    end
  end
end
