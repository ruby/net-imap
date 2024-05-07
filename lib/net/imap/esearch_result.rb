# frozen_string_literal: true

module Net
  class IMAP
    # An "extended search" response (+ESEARCH+).  ESearchResult should be
    # returned (instead of SearchResult) by IMAP#search, IMAP#uid_search,
    # IMAP#sort, and IMAP#uid_sort under any of the following conditions:
    #
    # * +return+ options were specified for IMAP#search or IMAP#uid_search.
    #   The server must support a search extension which allows
    #   RFC4466[https://www.rfc-editor.org/rfc/rfc4466.html] +return+ options,
    #   such as +ESEARCH+, +PARTIAL+, or +IMAP4rev2+.
    # * +return+ options were specified for IMAP#sort or IMAP#uid_sort.  The
    #   server must support the +ESORT+ extension
    #   {[RFC5267]}[https://www.rfc-editor.org/rfc/rfc5267.html#section-3]
    # * The server supports +IMAP4rev2+ but _not_ +IMAP4rev1+, or +IMAP4rev2+
    #   has been enabled.  +IMAP4rev2+ requires +ESEARCH+ results.
    #
    # Note that some servers may claim to support a search extension which
    # requires an +ESEARCH+ result, such as +PARTIAL+, but still only return a
    # +SEARCH+ result when +return+ options are specified.
    #
    # Some search extensions may result in the server sending ESearchResult
    # responses after the initiating command has completed.  Use
    # IMAP#add_response_handler to handle these responses.
    class ESearchResult < Data.define(:tag, :uid, :data)
      def initialize(tag: nil, uid: nil, data: nil)
        tag  => String       | nil; tag = -tag if tag
        uid  => true | false | nil; uid = !!uid
        data => Array        | nil; data ||= []; data.freeze
        super
      end

      # :call-seq: to_a -> Array of integers
      #
      # When either #all or #partial contains a SequenceSet of message sequence
      # numbers or UIDs, +to_a+ returns that set as an array of integers.
      #
      # When both #all and #partial are +nil+, either because the server
      # returned no results or because +ALL+ and +PARTIAL+ were not included in
      # the IMAP#search +RETURN+ options, #to_a returns an empty array.
      #
      # Note that SearchResult also implements +to_a+, so it can be used without
      # checking if the server returned +SEARCH+ or +ESEARCH+ data.
      def to_a; all&.numbers || partial&.to_a || [] end

      ##
      # attr_reader: tag
      #
      # The tag string for the command that caused this response to be returned.
      #
      # When +nil+, this response was not caused by a particular command.

      ##
      # attr_reader: uid
      #
      # Indicates whether #data in this response refers to UIDs (when +true+) or
      # to message sequence numbers (when +false+).

      ##
      alias uid? uid

      ##
      # attr_reader: data
      #
      # Search return data, as an array of <tt>[name, value]</tt> pairs.  Most
      # return data corresponds to a search +return+ option with the same name.
      #
      # Note that some return data names may be used more than once per result.
      #
      # This data can be more simply retrieved by #min, #max, #all, #count,
      # #modseq, and other methods.

      # :call-seq: min -> integer or nil
      #
      # The lowest message number/UID that satisfies the SEARCH criteria.
      #
      # Returns +nil+ when the associated search command has no results, or when
      # the +MIN+ return option wasn't specified.
      #
      # Requires +ESEARCH+ {[RFC4731]}[https://www.rfc-editor.org/rfc/rfc4731.html#section-3.1] or
      # +IMAP4rev2+ {[RFC9051]}[https://www.rfc-editor.org/rfc/rfc9051.html#section-7.3.4].
      def min;        data.assoc("MIN")&.last        end

      # :call-seq: max -> integer or nil
      #
      # The highest message number/UID that satisfies the SEARCH criteria.
      #
      # Returns +nil+ when the associated search command has no results, or when
      # the +MAX+ return option wasn't specified.
      #
      # Requires +ESEARCH+ {[RFC4731]}[https://www.rfc-editor.org/rfc/rfc4731.html#section-3.1] or
      # +IMAP4rev2+ {[RFC9051]}[https://www.rfc-editor.org/rfc/rfc9051.html#section-7.3.4].
      def max;        data.assoc("MAX")&.last        end

      # :call-seq: all -> sequence set or nil
      #
      # A SequenceSet containing all message sequence numbers or UIDs that
      # satisfy the SEARCH criteria.
      #
      # Returns +nil+ when the associated search command has no results, or when
      # the +ALL+ return option was not specified but other return options were.
      #
      # Requires +ESEARCH+ {[RFC4731]}[https://www.rfc-editor.org/rfc/rfc4731.html#section-3.1] or
      # +IMAP4rev2+ {[RFC9051]}[https://www.rfc-editor.org/rfc/rfc9051.html#section-7.3.4].
      #
      # See also: #to_a
      def all;        data.assoc("ALL")&.last        end

      # :call-seq: count -> integer or nil
      #
      # Returns the number of messages that satisfy the SEARCH criteria.
      #
      # Returns +nil+ when the associated search command has no results, or when
      # the +COUNT+ return option wasn't specified.
      #
      # Requires +ESEARCH+ {[RFC4731]}[https://www.rfc-editor.org/rfc/rfc4731.html#section-3.1] or
      # +IMAP4rev2+ {[RFC9051]}[https://www.rfc-editor.org/rfc/rfc9051.html#section-7.3.4].
      def count;      data.assoc("COUNT")&.last      end

      # :call-seq: modseq -> integer or nil
      #
      # The highest +mod-sequence+ of all messages being returned.
      #
      # Returns +nil+ when the associated search command has no results, or when
      # the +MODSEQ+ search criterion wasn't specified.
      #
      # Note that there is no search +return+ option for +MODSEQ+.  It will be
      # returned whenever the +CONDSTORE+ extension has been enabled.  Using the
      # +MODSEQ+ search criteria will implicitly enable +CONDSTORE+.
      #
      # Requires +CONDSTORE+ {[RFC7162]}[https://www.rfc-editor.org/rfc/rfc7162.html]
      # and +ESEARCH+ {[RFC4731]}[https://www.rfc-editor.org/rfc/rfc4731.html#section-3.2].
      def modseq;     data.assoc("MODSEQ")&.last     end

      # Superclass for AddToContext and RemoveFromContext, returned by
      # ESearchResult#addto, ESearchResult#removefrom, and
      # ESearchResult#updates.
      #
      # Use the +UPDATE+ search +return+ option to request update notifications.
      # Update notifications are sent after the searching command completes, as
      # and when the search results change.
      #
      # Requires <tt>CONTEXT=SEARCH</tt>/<tt>CONTEXT=SORT</tt>
      # {[RFC5267]}[https://www.rfc-editor.org/rfc/rfc5267.html]
      class ContextUpdate < Data.define(:position, :set)
        def initialize(position:, set:)
          position = NumValidator.ensure_number(position)
          set = SequenceSet[set]
          super
        end

        ##
        # attr_reader: position
        #
        # The position in the updated search context where results will be
        # inserted or removed, where the first position is one.
        #
        # When +position+ is zero, the results may be inserted or removed into
        # the result list in mailbox order.

        ##
        # attr_reader: set
        #
        # A SequenceSet of updates to the search context.

        ##
        # method: set

      end

      # Returned by ESearchResult#addto and ESearchResult#updates.
      #
      # Requires <tt>CONTEXT=SEARCH</tt>/<tt>CONTEXT=SORT</tt>
      # {[RFC5267]}[https://www.rfc-editor.org/rfc/rfc5267.html]
      class AddToContext < ContextUpdate
      end

      # Returned by ESearchResult#removefrom and ESearchResult#updates.
      #
      # Requires <tt>CONTEXT=SEARCH</tt>/<tt>CONTEXT=SORT</tt>
      # {[RFC5267]}[https://www.rfc-editor.org/rfc/rfc5267.html]
      class RemoveFromContext < ContextUpdate

      end

      # :call-seq: updates -> array of context updates, or nil
      #
      # Returns an array of ContextUpdate updates, which indicate additions to
      # or removals from the result list for the command issued with #tag.
      #
      # Use the +UPDATE+ search +return+ option to request update notifications.
      # Update notifications are sent after the searching command completes, as
      # and when the search results change.
      #
      # Requires <tt>CONTEXT=SEARCH</tt> or <tt>CONTEXT=SORT</tt>
      # {[RFC5267]}[https://www.rfc-editor.org/rfc/rfc5267.html]
      def updates
        data.flat_map { %w[ADDTO REMOVEFROM].include?(_1) ? _2 : [] }
      end

      # Returned by ESearchResult#partial.
      #
      # Requires +PARTIAL+ {[RFC9394]}[https://www.rfc-editor.org/rfc/rfc9394.html]
      # or <tt>CONTEXT=SEARCH</tt>/<tt>CONTEXT=SORT</tt>
      # {[RFC5267]}[https://www.rfc-editor.org/rfc/rfc5267.html]
      #
      # See also: #to_a
      class PartialResult < Data.define(:range, :results)
        def initialize(range:, results:)
          range   => Range
          results => SequenceSet | nil
          super
        end

        ##
        # method: range
        # :call-seq: range -> range

        ##
        # method: results
        # :call-seq: results -> sequence set or nil

        # Converts #results to an array of integers.
        #
        # See also: ESearchResult#to_a.
        def to_a; results&.numbers || [] end
      end

      # :call-seq: partial -> PartialResult or nil
      #
      # A PartialResult containing a subset of the message sequence numbers or
      # UIDs that satisfy the SEARCH criteria.
      #
      # Requires +PARTIAL+ {[RFC9394]}[https://www.rfc-editor.org/rfc/rfc9394.html]
      # or <tt>CONTEXT=SEARCH</tt>/<tt>CONTEXT=SORT</tt>
      # {[RFC5267]}[https://www.rfc-editor.org/rfc/rfc5267.html]
      #
      # See also: #to_a
      def partial;    data.assoc("PARTIAL")&.last    end

      # :call-seq: relevancy -> array of integers
      #
      # Return an array of relevancy scores for each message that satisfies the
      # SEARCH criteria.  Scores are given in the range 1-100, where 100 is the
      # highest relevancy.
      #
      # Requires <tt>SEARCH=FUZZY</tt>
      # {[RFC6203]}[https://www.rfc-editor.org/rfc/rfc6203.html]
      def relevancy;  data.assoc("RELEVANCY")&.last  end

    end
  end
end
