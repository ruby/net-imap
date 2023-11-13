# frozen_string_literal: true

module Net
  class IMAP

    ##
    # An IMAP {sequence
    # set}[https://www.rfc-editor.org/rfc/rfc9051.html#section-4.1.1],
    # is a set of message sequence numbers or unique identifier numbers
    # ("UIDs").  It contains numbers and ranges of numbers.  The numbers are all
    # non-zero unsigned 32-bit integers and one special value, <tt>*</tt>, that
    # represents the largest value in the mailbox.
    #
    # *NOTE:* This SequenceSet class is currently a placeholder for unhandled
    # extension data.  All it does now is validate.  It will be expanded to a
    # full API in a future release.
    class SequenceSet

      def self.[](str) new(str).freeze end

      def initialize(input)
        @atom = -String.try_convert(input)
        validate
      end

      # Returns the IMAP string representation.  In the IMAP grammar,
      # +sequence-set+ is a subset of +atom+ which is a subset of +astring+.
      attr_accessor :atom

      # Returns #atom.  In the IMAP grammar, +atom+ is a subset of +astring+.
      alias astring atom

      # Returns the value of #atom
      alias to_s atom

      # Hash equality requires the same encoded #atom representation.
      #
      #   Net::IMAP::SequenceSet["1:3"]  .eql? Net::IMAP::SequenceSet["1:3"]  # => true
      #   Net::IMAP::SequenceSet["1,2,3"].eql? Net::IMAP::SequenceSet["1:3"]  # => false
      #   Net::IMAP::SequenceSet["1,3"]  .eql? Net::IMAP::SequenceSet["3,1"]  # => false
      #   Net::IMAP::SequenceSet["9,1:*"].eql? Net::IMAP::SequenceSet["1:*"]  # => false
      #
      def eql?(other) self.class == other.class && atom == other.atom end
      alias == eql?

      # See #eql?
      def hash; [self.class. atom].hash end

      def inspect
        (frozen? ? "%s[%p]" : "#<%s %p>") % [self.class, to_s]
      end

      # Unstable API, for internal use only (Net::IMAP#validate_data)
      def validate # :nodoc:
        ResponseParser::Patterns::SEQUENCE_SET_STR.match?(@atom) or
          raise ArgumentError, "invalid sequence-set: %p" % [input]
        true
      end

      # Unstable API, for internal use only (Net::IMAP#send_data)
      def send_data(imap, tag) # :nodoc:
        imap.__send__(:put_string, atom)
      end

    end
  end
end
