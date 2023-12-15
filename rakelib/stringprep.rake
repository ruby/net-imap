# frozen_string_literal: true

require_relative "string_prep_tables_generator"

generator = StringPrepTablesGenerator.new
GENERATED_RUBY = FileList.new
GENERATED_RUBY.include "#{generator.tables_dir}.rb"
GENERATED_RUBY.include generator.tables_dir
table_deps = GENERATED_RUBY.dup.include generator.rb_deps

file generator.json_filename => generator.json_deps do |t|
  generator.generate_json_data_file
end

directory "lib/net/imap/sasl"
directory generator.tables_dir

file "#{generator.tables_dir}.rb" => generator.rb_deps do |t|
  File.write t.name, generator.stringprep_rb
end

rule(%r{#{Regexp.escape(generator.tables_dir)}/[^/]+\.rb} => table_deps) do |t|
  const_name = File.basename(t.name, ".rb").upcase.to_sym
  File.write t.name, generator.stringprep_table_file(const_name)
end

task "stringprep:tables": table_deps do
  generator.table_files.map { Rake::Task[_1] }.each do |t|
    t.invoke
  end
end

CLEAN.include   generator.clean_deps
CLOBBER.include GENERATED_RUBY

task "stringprep:tables": GENERATED_RUBY
task test: "stringprep:tables"
