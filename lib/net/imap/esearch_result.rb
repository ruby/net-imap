# frozen_string_literal: true

module Net
  class IMAP
    # An Extended search result which is returned by IMAP#search,
    # IMAP#uid_search, IMAP#sort, and IMAP#uid_sort instead of SearchResult
    # under the following conditions:
    #
    # * The server supports +ESEARCH+ and a +return+ option was specified.
    # * The server supports +ESORT+ and a +return+ options was specified (for
    #   IMAP#sort and IMAP#uid_sort).
    # * The server supports +IMAP4rev2+ but _not_ +IMAP4rev1+.
    # * +IMAP4rev2+ has been enabled.
    #
    class ESearchResult < Struct.new(:tag, :uid, :data)
      alias uid? uid

      ##
      # method: tag
      # :call-seq: tag -> string or nil
      #
      # The tag of the command that caused the response to be returned.
      #
      # If it is missing, then the response was not caused by a particular IMAP
      # command.

      ##
      # method: uid
      # :call-seq: uid -> boolean
      #
      # When true, all #data in the +ESEARCH+ response refers to UIDs;
      # otherwise, all returned #data refers to message sequence numbers.

      ##
      # method: data :call-seq: data -> array of [name, value] pairs
      #
      # Search return data, which can also be retrieved by #min, #max, #all,
      # #count, #modseq, and other methods.  Most names correspond to an
      # IMAP#search +return+ option of the same name.
      #
      # Stored as an array of (name, value) pairs rather than as a hash, because
      # extensions may allow the same name to be used more than once per result.

      # :call-seq: min -> integer or nil
      #
      # The lowest message number/UID that satisfies the SEARCH criteria.
      # Returns nil when the associated search command has no results, or when
      # the +MIN+ return option wasn't specified.
      #
      # See +ESEARCH+ ({RFC4731
      # §3.1}[https://www.rfc-editor.org/rfc/rfc4731.html#section-3.1]) or
      # +IMAP4rev2+ ({RFC9051
      # §7.3.4}[https://www.rfc-editor.org/rfc/rfc9051.html#section-7.3.4])
      def min;        data.assoc("MIN")&.last        end

      # :call-seq: max -> integer or nil
      #
      # The highest message number/UID that satisfies the SEARCH criteria.
      # Returns nil when the associated search command has no results, or when
      # the +MAX+ return option wasn't specified.
      #
      # See +ESEARCH+ ({RFC4731
      # §3.1}[https://www.rfc-editor.org/rfc/rfc4731.html#section-3.1]) or
      # +IMAP4rev2+ ({RFC9051
      # §7.3.4}[https://www.rfc-editor.org/rfc/rfc9051.html#section-7.3.4])
      def max;        data.assoc("MAX")&.last        end

      # :call-seq: all -> sequence set or nil
      #
      # A SequenceSet containing all message numbers/UIDs that satisfy the
      # SEARCH criteria.  Returns +nil+ when the associated search command has
      # no results, or when the +ALL+ return option wasn't specified.
      #
      # See +ESEARCH+ ({RFC4731
      # §3.1}[https://www.rfc-editor.org/rfc/rfc4731.html#section-3.1]) or
      # +IMAP4rev2+ ({RFC9051
      # §7.3.4}[https://www.rfc-editor.org/rfc/rfc9051.html#section-7.3.4])
      def all;        data.assoc("ALL")&.last        end

      # :call-seq: count -> integer or nil
      #
      # Returns the number of messages that satisfy the SEARCH criteria.
      # Returns +nil+ when the associated search command has no results.
      #
      # See +ESEARCH+ ({RFC4731
      # §3.1}[https://www.rfc-editor.org/rfc/rfc4731.html#section-3.1]) or
      # +IMAP4rev2+ ({RFC9051
      # §7.3.4}[https://www.rfc-editor.org/rfc/rfc9051.html#section-7.3.4])
      def count;      data.assoc("COUNT")&.last      end

      # :call-seq: modseq -> integer or nil
      #
      # The highest +mod-sequence+ of all messages in the set that satisfy the
      # SEARCH criteria and result options.  Returns +nil+ when the associated
      # search command has no results.
      #
      # See +CONDSTORE+
      # {[RFC7162]}[https://www.rfc-editor.org/rfc/rfc7162.html].
      def modseq;     data.assoc("MODSEQ")&.last     end

      class ContextUpdate < Struct.new(:position, :set)
      end

      class AddToContext < ContextUpdate
      end

      class RemoveFromContext < ContextUpdate
      end

      # :call-seq: addto -> array of insertion updates, or nil
      #
      # Notification of updates, inserting messages into the result list for the
      # command issued with #tag.
      #
      # See <tt>CONTEXT=SEARCH</tt>/<tt>CONTEXT=SORT</tt>
      # {[RFC5267]}[https://www.rfc-editor.org/rfc/rfc5267.html]
      def addto
        data.flat_map { _1 == "ADDTO" ? _2 : [] }
      end

      # :call-seq: removefrom -> array of removal updates, or nil
      #
      # Notification of updates, removing messages into the result list for the
      # command issued with #tag.
      #
      # See <tt>CONTEXT=SEARCH</tt>/<tt>CONTEXT=SORT</tt>
      # {[RFC5267]}[https://www.rfc-editor.org/rfc/rfc5267.html]
      def removefrom
        data.flat_map { _1 == "REMOVEFROM" ? _2 : [] }
      end

      # :call-seq: updates -> array of context updates, or nil
      #
      # Notification of updates, inserting or removing messages to or from the
      # result list for the command issued with #tag.
      #
      # See <tt>CONTEXT=SEARCH</tt>/<tt>CONTEXT=SORT</tt>
      # {[RFC5267]}[https://www.rfc-editor.org/rfc/rfc5267.html]
      def updates
        data.flat_map { %w[ADDTO REMOVEFROM].include?(_1) ? _2 : [] }
      end

      # See +PARTIAL+ {[RFC9394]}[https://www.rfc-editor.org/rfc/rfc9394.html]
      # or <tt>CONTEXT=SEARCH</tt>/<tt>CONTEXT=SORT</tt>
      # {[RFC5267]}[https://www.rfc-editor.org/rfc/rfc5267.html]
      class PartialResult < Struct.new(:range, :results)
        ##
        # method: range
        # :call-seq: range -> range

        ##
        # method: results
        # :call-seq: results -> sequence set or nil
      end

      # :call-seq: partial -> PartialResult or nil
      #
      # Return a subset of the message numbers/UIDs that satisfy the SEARCH
      # criteria.
      #
      # See +PARTIAL+ {[RFC9394]}[https://www.rfc-editor.org/rfc/rfc9394.html]
      # or <tt>CONTEXT=SEARCH</tt>/<tt>CONTEXT=SORT</tt>
      # {[RFC5267]}[https://www.rfc-editor.org/rfc/rfc5267.html]
      def partial;    data.assoc("PARTIAL")&.last    end

      # :call-seq: relevancy -> integer or nil
      #
      # Return a relevancy score for each message that satisfies the SEARCH
      # criteria.
      #
      # See <tt>SEARCH=FUZZY</tt>
      # {[RFC6203]}[https://www.rfc-editor.org/rfc/rfc6203.html]
      def relevancy;  data.assoc("RELEVANCY")&.last  end

    end
  end
end
