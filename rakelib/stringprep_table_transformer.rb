# frozen_string_literal: true

require "set" unless defined?(::Set)

# Converts RFC3454 tables into ranges, arrays, sets, regexps.
class StringPrepTableTransformer

  # valid UTF-8 can't contain these codepoints
  # checking for them anyway, using /\p{Cs}/  ;)
  SURROGATES_RANGE = 0xD800..0xDFFF

  def initialize(table_source)
    @table_source = table_source
  end

  def inspect; "#<#{self.class}>" end

  def tables;  @table_source.tables end
  def ranges;  @ranges  ||= tables.transform_values(&method(:to_ranges)) end
  def arrays;  @arrays  ||= ranges.transform_values{|t| t.flat_map(&:to_a) } end
  def sets;    @sets    ||= arrays.transform_values(&:to_set) end
  def regexps; @regexps ||= arrays.transform_values(&method(:to_regexp)) end

  def merged_tables_regex(*table_names, negate: false)
    table_names
      .flat_map { arrays.fetch _1 }
      .then { to_regexp(_1, negate: negate) }
  end

  private

  def to_ranges(table)
    (table.is_a?(Hash) ? table.keys : table)
      .map{|range| range.split(?-).map {|cp| Integer cp, 16} }
      .map{|s,e| s..(e || s)}
  end

  # Starting from a codepoints array (rather than ranges) to deduplicate merged
  # tables.
  def to_regexp(codepoints, negate: false)
    codepoints
      .grep_v(SURROGATES_RANGE) # remove surrogate codepoints from C.5 and D.2
      .uniq.sort
      .chunk_while {|cp1,cp2| cp1 + 1 == cp2 }     # find contiguous chunks
      .map {|chunk| chunk.map{|cp| "%04x" % cp } } # convert to hex strings
      .partition {|chunk| chunk[1] }               # ranges vs singles
      .then {|ranges, singles|
        singles.flatten!
        [
          negate ? "^" : "",
          singles.flatten.any? ? "\\u{%s}" % singles.join(" ") : "",
          ranges.map {|r| "\\u{%s}-\\u{%s}" % [r.first, r.last] }.join,
          codepoints.any?(SURROGATES_RANGE) ? "\\p{Cs}" : "", # not necessary :)
        ].join
      }
      .then {|char_class| Regexp.new "[#{char_class}]" }
  end

end
