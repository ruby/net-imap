# frozen_string_literal: true

module Net
  class IMAP < Protocol

    # Net::IMAP::VanishedData represents the contents of a +VANISHED+ response,
    # which is described by the
    # {QRESYNC}[https://www.rfc-editor.org/rfc/rfc7162.html] extension.
    # [{RFC7162 §3.2.10}[https://www.rfc-editor.org/rfc/rfc7162.html#section-3.2.10]].
    #
    # +VANISHED+ responses replace +EXPUNGE+ responses when either the
    # {QRESYNC}[https://www.rfc-editor.org/rfc/rfc7162.html] or the
    # {UIDONLY}[https://www.rfc-editor.org/rfc/rfc9586.html] extension has been
    # enabled.
    class VanishedData

      # call-seq:
      #   VanishedData[uids, earlier] -> VanishedData
      #   VanishedData[uids:, earlier:] -> VanishedData
      #
      # Delegates to ::new.  Unlike ::new, ::[] can be given positional args.
      def self.[](uids_arg = nil, earlier_arg = nil, uids: nil, earlier: nil)
        if !(uids_arg.nil? && earlier_arg.nil?)
          if !(uids.nil? && earlier.nil?)
            raise ArgumentError, "do not combine positional and keyword args"
          else
            new(uids: uids_arg, earlier: earlier_arg)
          end
        else
          new(uids: uids, earlier: earlier)
        end
      end

      # SequenceSet of UIDs that have been permanently removed from the mailbox.
      attr_reader :uids

      # +true+ when the response was caused by Net::IMAP#uid_fetch with
      # <tt>vanished: true</tt> or Net::IMAP#select/Net::IMAP#examine with
      # <tt>qresync: true</tt>.
      #
      # +false+ when the response is used to announce message removals within an
      # already selected mailbox.
      attr_reader :earlier
      alias earlier? earlier

      # Returns a new VanishedData object.
      #
      # * +uids+ will be coerced by SequenceSet.new.
      # * +earlier+ will be converted to +true+ or +false+
      #
      # Arguments must not be +nil+.
      def initialize(uids:, earlier:)
        raise ArgumentError, "uids must not be nil" if uids.nil?
        raise ArgumentError, "earlier must be true or false" if earlier.nil?
        @uids    = SequenceSet.new(uids)
        @earlier = !!earlier
      end

      # Delegates to #uids.
      #
      # See SequenceSet#numbers.
      def to_a; uids.numbers end

      # Returns a hash with +:uids+ and +:earlier+ keys and the corresponding
      # #uid and #earlier values.
      def deconstruct_keys(keys) {uids: uids, earlier: earlier} end

      # :call-seq: self == other -> true or false
      #
      # Returns +true+ when the other VanishedData represents the same #uids and
      # has the same value for #earlier?.
      def ==(other)
        self.class == other.class &&
          uids == other.uids &&
          earlier == other.earlier
      end

      # :call-seq: eql?(other) -> true or false
      #
      # Hash equality requires the same encoded string representation for #uids.
      def eql?(other)
        self.class == other.class &&
          uids.eql?(other.uids) &&
          earlier.eql?(other.earlier)
      end

      def hash # :nodoc:
        [self.class, uids, earlier].hash
      end

    end
  end
end
