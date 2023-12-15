# frozen_string_literal: true

# Extracts the Appendix tables from RFC3454 into a #tables hash of table name to
# codepoints array or mapping hash.  Table #titles are also extracted.
class RFC3454TableParser
  STRINGPREP_RFC_FILE  = "rfcs/rfc3454.txt"
  STRINGPREP_JSON_FILE = "rfcs/rfc3454-stringprep_tables.json"

  attr_reader :json_filename, :rfc_filename

  def initialize(rfc_filename:  STRINGPREP_RFC_FILE,
                 json_filename: STRINGPREP_JSON_FILE)
    @rfc_filename  = rfc_filename
    @json_filename = json_filename
  end

  def inspect; "#<#{self.class}>" end

  def tables; @tables || load_from_json.first end
  def titles; @titles || load_from_json.last  end

  def table_names;   tables.keys         end
  def mapping_names; mapping_tables.keys end

  def mapping_tables
    @mapping_tables ||= tables
      .select { _2.is_a?(Hash) }
      .transform_values { to_map _1 }
  end

  def write_json_file!
    require "json"
    rfc_filename
      .then { File.read                 _1 }
      .then { parse_rfc_text            _1 }
      .then { JSON.pretty_generate      _1 }
      .then { File.write json_filename, _1 }
  end

  def load_from_json
    write_json_file! unless File.exist?(json_filename)
    require "json"
    @tables = json_filename
      .then(&File.method(:read))
      .then(&JSON.method(:parse))
    @titles = @tables.delete "titles"
    [@tables, @titles]
  end

  def rake_deps;   Rake::FileList.new __FILE__, rfc_filename  end
  def rake_output; Rake::FileList.new           json_filename end

  private

  # TODO: DRY with unicode_normalize
  def to_map(table)
    table.to_hash
      .to_h { [Integer(_1, 16), _2.map {|cp| Integer(cp, 16) }] }
      .to_h { [[_1].pack("U*"), _2.pack("U*")] }
  end

  def parse_rfc_text(rfc3454_text)
    titles = {}
    tables, = rfc3454_text
      .lines
      .each_with_object([]) {|line, acc|
        current, table = acc.last
        case line
        when /^([A-D]\.[1-9](?:\.[1-9])?) (.*)/
          titles[$1] = $2
        when /^ {3}-{5} Start Table (\S*)/
          acc << [$1, []]
        when /^ {3}-{5} End Table /
          acc << [nil, nil]
        when /^ {3}([0-9A-F]+); ([ 0-9A-F]*)(?:;[^;]*)$/  # mapping tables
          table << [$1, $2.split(/ +/)] if current
        when /^ {3}([-0-9A-F]+)(?:;[^;]*)?$/              # regular tables
          table << $1 if current
        when /^ {3}(.*)/
          raise "expected to match %p" % $1 if current
        end
      }
      .to_h.compact
      .transform_values {|t| t.first.size == 2 ? t.to_h : t }
    tables["titles"] = titles
    tables
  end

end
