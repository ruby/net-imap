# frozen_string_literal: true

module Net
  class IMAP < Protocol

    # UIDPlusData represents the ResponseCode#data that accompanies the
    # +APPENDUID+ and +COPYUID+ {response codes}[rdoc-ref:ResponseCode].
    #
    # A server that supports +UIDPLUS+ should send UIDPlusData in response to
    # the append[rdoc-ref:Net::IMAP#append], copy[rdoc-ref:Net::IMAP#copy],
    # move[rdoc-ref:Net::IMAP#move], {uid copy}[rdoc-ref:Net::IMAP#uid_copy],
    # and {uid move}[rdoc-ref:Net::IMAP#uid_move] commands---unless the
    # destination mailbox reports +UIDNOTSTICKY+.
    #
    # Note that append[rdoc-ref:Net::IMAP#append], copy[rdoc-ref:Net::IMAP#copy]
    # and {uid_copy}[rdoc-ref:Net::IMAP#uid_copy] return UIDPlusData in their
    # TaggedResponse.  But move[rdoc-ref:Net::IMAP#copy] and
    # {uid_move}[rdoc-ref:Net::IMAP#uid_move] _should_ send UIDPlusData in an
    # UntaggedResponse response before sending their TaggedResponse.  However
    # some servers do send UIDPlusData in the TaggedResponse for +MOVE+
    # commands---this complies with the older +UIDPLUS+ specification but is
    # discouraged by the +MOVE+ extension and disallowed by +IMAP4rev2+.
    #
    # == Required capability
    # Requires either +UIDPLUS+ [RFC4315[https://www.rfc-editor.org/rfc/rfc4315]]
    # or +IMAP4rev2+ capability.
    #
    class UIDPlusData < Struct.new(:uidvalidity, :source_uids, :assigned_uids)
      ##
      # method: uidvalidity
      # :call-seq: uidvalidity -> nonzero uint32
      #
      # The UIDVALIDITY of the destination mailbox.

      ##
      # method: source_uids
      # :call-seq: source_uids -> nil or an array of nonzero uint32
      #
      # The UIDs of the copied or moved messages.
      #
      # Note:: Returns +nil+ for Net::IMAP#append.

      ##
      # method: assigned_uids
      # :call-seq: assigned_uids -> an array of nonzero uint32
      #
      # The newly assigned UIDs of the copied, moved, or appended messages.
      #
      # Note:: This always returns an array, even when it contains only one UID.

      ##
      # :call-seq: uid_mapping -> nil or a hash
      #
      # Returns a hash mapping each source UID to the newly assigned destination
      # UID.
      #
      # Note:: Returns +nil+ for Net::IMAP#append.
      def uid_mapping
        source_uids&.zip(assigned_uids)&.to_h
      end
    end

    # AppendUIDData represents the ResponseCode#data that accompanies the
    # +APPENDUID+ {response code}[rdoc-ref:ResponseCode].
    #
    # A server that supports +UIDPLUS+ (or +IMAP4rev2+) should send
    # AppendUIDData inside every TaggedResponse returned by the
    # append[rdoc-ref:Net::IMAP#append] command---unless the target mailbox
    # reports +UIDNOTSTICKY+.
    #
    # == Required capability
    # Requires either +UIDPLUS+ [RFC4315[https://www.rfc-editor.org/rfc/rfc4315]]
    # or +IMAP4rev2+ capability.
    class AppendUIDData < Data.define(:uidvalidity, :assigned_uids)
      def initialize(uidvalidity:, assigned_uids:)
        uidvalidity   = Integer(uidvalidity)
        assigned_uids = SequenceSet[assigned_uids]
        NumValidator.ensure_nz_number(uidvalidity)
        if assigned_uids.include_star?
          raise DataFormatError, "uid-set cannot contain '*'"
        end
        super
      end

      ##
      # attr_reader: uidvalidity
      # :call-seq: uidvalidity -> nonzero uint32
      #
      # The UIDVALIDITY of the destination mailbox.

      ##
      # attr_reader: assigned_uids
      #
      # A SequenceSet with the newly assigned UIDs of the appended messages.

      # Returns the number of messages that have been appended.
      def size
        assigned_uids.count_with_duplicates
      end
    end

  end
end
