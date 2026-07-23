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

desc "Output coverage data report, and error when threshholds aren't met"
task "coverage:report" do
  require "simplecov"
  SimpleCov.collate "coverage/.resultset.json" do
    coverage(:line) do
      minimum           90
      minimum_per_file  40
    end
  end
end
