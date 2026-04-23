# frozen_string_literal: true

require "date"

require_relative "errors"

module Net
  class IMAP < Protocol

    private

    def validate_data(data)
      case data
      when nil
      when String
      when Integer
        NumValidator.ensure_number(data)
      when Array
        if data[0] == 'CHANGEDSINCE'
          NumValidator.ensure_mod_sequence_value(data[1])
        else
          data.each do |i|
            validate_data(i)
          end
        end
      when Time, Date, DateTime
      when Symbol
        Flag.validate(data)
      else
        data.validate
      end
    end

    def send_data(data, tag = nil)
      case data
      when nil
        put_string("NIL")
      when String
        send_string_data(data, tag)
      when Integer
        send_number_data(data)
      when Array
        send_list_data(data, tag)
      when Time, DateTime
        send_time_data(data)
      when Date
        send_date_data(data)
      when Symbol
        Flag[data].send_data(self, tag)
      else
        data.send_data(self, tag)
      end
    end

    def send_string_data(str, tag = nil)
      if str.empty?
        put_string('""')
      elsif str.match?(/[\r\n]/n)
        # literal, because multiline
        send_literal(str, tag)
      elsif !str.ascii_only?
        if @utf8_strings
          # quoted string
          send_quoted_string(str)
        else
          # literal, because of non-ASCII bytes
          send_literal(str, tag)
        end
      elsif str.match?(/[(){ \x00-\x1f\x7f%*"\\]/n)
        # quoted string
        send_quoted_string(str)
      else
        put_string(str)
      end
    end

    def send_quoted_string(str)
      put_string('"' + str.gsub(/["\\]/, "\\\\\\&") + '"')
    end

    def send_binary_literal(*a, **kw) send_literal(*a, **kw, binary: true) end

    # `non_sync` is an optional tri-state flag:
    # * `true`  -> Force non-synchronizing `LITERAL+`/`LITERAL-` behavior.
    #   TODO: raise or warn when capabilities don't allow non_sync.
    # * `false` -> Force normal synchronizing literal behavior.
    # * `nil`   -> (default) Currently behaves like `false` (will be dynamic).
    #   TODO: Dynamic, based on capabilities and bytesize.
    def send_literal(str, tag = nil, binary: false, non_sync: nil)
      synchronize do
        prefix = "~" if binary
        plus = "+" if non_sync
        put_string("#{prefix}{#{str.bytesize}#{plus}}\r\n")
        if non_sync
          put_string(str)
          return
        end
        @continued_command_tag = tag
        @continuation_request_exception = nil
        begin
          @continuation_request_arrival.wait
          e = @continuation_request_exception || @exception
          raise e if e
          put_string(str)
        ensure
          @continued_command_tag = nil
          @continuation_request_exception = nil
        end
      end
    end

    def send_number_data(num)
      put_string(num.to_s)
    end

    def send_list_data(list, tag = nil)
      put_string("(")
      first = true
      list.each do |i|
        if first
          first = false
        else
          put_string(" ")
        end
        send_data(i, tag)
      end
      put_string(")")
    end

    def send_date_data(date) put_string Net::IMAP.encode_date(date) end
    def send_time_data(time) put_string Net::IMAP.encode_time(time) end

    # simplistic emulation of CommandData = Data.define(:data)
    class CommandData # :nodoc:
      class << self
        def new(arg = nil, data: arg) super(data: data) end
        alias :[] :new
      end

      def initialize(data:)
        @data = data
        freeze
      end

      attr_reader :data

      def to_h(&block) block ? to_h.to_h(&block) : { data: data } end
      def ==(other)   self.class === other && to_h  ==  other.to_h  end
      def eql?(other) self.class === other && to_h.eql?(other.to_h) end

      # following class definition goes beyond the basic Data.define(:data)
      ##

      def self.validate(...)
        data = new(...)
        data.validate
        data
      end

      def send_data(imap, tag)
        raise NoMethodError, "#{self.class} must implement #{__method__}"
      end

      def validate
      end
    end

    # Represents IMAP +text+ data, which may contain any 7-bit ASCII character,
    # except for +NULL+, +CR+, or +LF+.  +text+ is extended to allow any
    # multibyte +UTF-8+ character when either +UTF8=ACCEPT+ or +IMAP4rev2+ have
    # been enabled, or when the server supports only +IMAP4rev2+ and not earlier
    # IMAP revisions, or when the server advertises +UTF8=ONLY+.
    #
    # NOTE: The current implementation does not validate whether the connection
    # currently supports UTF-8.  Future versions may change.
    #
    # The string's bytes must be valid ASCII or valid UTF-8.  The string's
    # reported encoding is ignored, but the string is _not_ transcoded.
    class RawText < CommandData # :nodoc:
      def initialize(data:)
        data = String(data.to_str)
        data = if [Encoding::ASCII, Encoding::UTF_8].include?(data.encoding)
          -data
        elsif data.ascii_only?
          -(data.dup.force_encoding("ASCII"))
        else
          -(data.dup.force_encoding("UTF-8"))
        end
        super
        validate
      end

      def validate
        if data.include?("\0")
          raise DataFormatError, "NULL byte must be binary literal encoded"
        elsif !data.valid_encoding?
          raise DataFormatError, "invalid UTF-8 must be literal encoded"
        elsif /[\r\n]/.match?(data)
          raise DataFormatError, "CR and LF bytes must be literal encoded"
        end
      end

      def ascii_only?; data.ascii_only? end

      def send_data(imap, tag) imap.__send__(:put_string, data) end
    end

    class RawData < CommandData # :nodoc:
      def initialize(data:)
        data = split_parts(data)
        super
        validate
      end

      def send_data(imap, tag) data.each do _1.send_data(imap, tag) end end

      def validate
        return unless RawText === data.last
        text = data.last.data
        if text.rindex(/~?\{[1-9]\d*\+?\}\z/n)
          raise DataFormatError, "RawData cannot end with literal continuation"
        end
      end

      private

      def split_parts(data)
        data = data.b # dups and ensures BINARY encoding
        parts = []
        while data.match(/(~)?\{(0|[1-9]\d*)(\+)?\}\r\n/n)
          text, binary, bytesize, non_sync, data = $`, !!$1, $2, !!$3, $'
          bytesize = Integer bytesize, 10
          parts << RawText[text] unless text.empty?
          parts << extract_literal(data,
                                   binary: binary,
                                   bytesize: bytesize,
                                   non_sync: non_sync)
          data[0, bytesize] = ""
        end
        parts << RawText[data] unless data.empty?
        parts
      end

      def extract_literal(data, binary:, bytesize:, non_sync:)
        if data.bytesize < bytesize
          raise DataFormatError, "Too few bytes in string for literal, " \
            "expected: %s, remaining: %s" % [bytesize, data.bytesize]
        end
        literal = data.byteslice(0, bytesize)
        (binary ? Literal8 : Literal).new(data: literal, non_sync: non_sync)
      end
    end

    class Atom < CommandData # :nodoc:
      def initialize(**)
        super
        validate
      end

      def validate
        data.to_s.ascii_only? \
          or raise DataFormatError, "#{self.class} must be ASCII only"
        data.match?(ResponseParser::Patterns::ATOM_SPECIALS) \
          and raise DataFormatError, "#{self.class} must not contain atom-specials"
      end

      def send_data(imap, tag)
        imap.__send__(:put_string, data.to_s)
      end
    end

    class Flag < Atom # :nodoc:
      def send_data(imap, tag)
        imap.__send__(:put_string, "\\#{data}")
      end
    end

    class QuotedString # :nodoc:
      def send_data(imap, tag)
        imap.__send__(:send_quoted_string, @data)
      end

      def validate
      end

      private

      def initialize(data)
        @data = data
      end
    end

    class Literal # :nodoc:
      class << self
        def new(_data = nil, _non_sync = nil, data: _data, non_sync: _non_sync)
          super(data: data, non_sync: non_sync)
        end
        alias :[] :new
      end

      attr_reader :data, :non_sync

      def to_h(&block) block ? to_h.to_h(&block) : { data: data, non_sync: non_sync } end
      def ==(other)   self.class === other && to_h  ==  other.to_h  end
      def eql?(other) self.class === other && to_h.eql?(other.to_h) end

      def initialize(data:, non_sync: nil)
        data = -String(data.to_str).b or
          raise DataFormatError, "#{self.class} expects string input"
        @data, @non_sync = data, non_sync
        validate
        freeze
      end

      def self.validate(...)
        data = new(...)
        data.validate
        data
      end

      def bytesize; data.bytesize end

      def validate
        if data.include?("\0")
          raise DataFormatError, "NULL byte not allowed in #{self.class}.  " \
            "Use #{Literal8} or a null-safe encoding."
        end
      end

      def send_data(imap, tag)
        imap.__send__(:send_literal, data, tag, non_sync: non_sync)
      end
    end

    class Literal8 < Literal # :nodoc:
      def validate; nil end # all bytes are okay

      def send_data(imap, tag)
        imap.__send__(:send_binary_literal, data, tag, non_sync: non_sync)
      end
    end

    class MessageSet # :nodoc:
      def send_data(imap, tag)
        imap.__send__(:put_string, format_internal(@data))
      end

      def validate
        validate_internal(@data)
      end

      private

      def initialize(data)
        @data = data
      end

      def format_internal(data)
        case data
        when "*"
          return data
        when Integer
          if data == -1
            return "*"
          else
            return data.to_s
          end
        when Range
          return format_internal(data.first) +
            ":" + format_internal(data.last)
        when Array
          return data.collect {|i| format_internal(i)}.join(",")
        when ThreadMember
          return data.seqno.to_s +
            ":" + data.children.collect {|i| format_internal(i).join(",")}
        end
      end

      def validate_internal(data)
        case data
        when "*"
        when Integer
          NumValidator.ensure_nz_number(data)
        when Range
        when Array
          data.each do |i|
            validate_internal(i)
          end
        when ThreadMember
          data.children.each do |i|
            validate_internal(i)
          end
        else
          raise DataFormatError, data.inspect
        end
      end
    end

    class ClientID # :nodoc:

      def send_data(imap, tag)
        imap.__send__(:send_data, format_internal(@data), tag)
      end

      def validate
        validate_internal(@data)
      end

      private

      def initialize(data)
        @data = data
      end

      def validate_internal(client_id)
        client_id.to_h.each do |k,v|
          unless StringFormatter.valid_string?(k)
            raise DataFormatError, client_id.inspect
          end
        end
      rescue NoMethodError, TypeError # to_h failed
        raise DataFormatError, client_id.inspect
      end

      def format_internal(client_id)
        return nil if client_id.nil?
        client_id.to_h.flat_map {|k,v|
          [StringFormatter.string(k), StringFormatter.nstring(v)]
        }
      end

    end

    module StringFormatter

      LITERAL_REGEX = /[\x80-\xff\r\n]/n

      module_function

      # Allows symbols in addition to strings
      def valid_string?(str)
        str.is_a?(Symbol) || str.respond_to?(:to_str)
      end

      # Allows nil, symbols, and strings
      def valid_nstring?(str)
        str.nil? || valid_string?(str)
      end

      # coerces using +to_s+
      def string(str)
        str = str.to_s
        if str =~ LITERAL_REGEX
          Literal.new(str)
        else
          QuotedString.new(str)
        end
      end

      # coerces non-nil using +to_s+
      def nstring(str)
        str.nil? ? nil : string(str)
      end

    end

  end
end
