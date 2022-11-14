# frozen_string_literal: true

module Net
  class IMAP < Protocol

    # Net::IMAP::ContinuationRequest represents command continuation requests.
    #
    # The command continuation request response is indicated by a "+" token
    # instead of a tag.  This form of response indicates that the server is
    # ready to accept the continuation of a command from the client.  The
    # remainder of this response is a line of text.
    #
    class ContinuationRequest < Struct.new(:data, :raw_data)
      ##
      # method: data
      # :call-seq: data -> ResponseText
      #
      # Returns a ResponseText object

      ##
      # method: raw_data
      # :call-seq: raw_data -> string
      #
      # the raw response data
    end

    # Net::IMAP::UntaggedResponse represents untagged responses.
    #
    # Data transmitted by the server to the client and status responses
    # that do not indicate command completion are prefixed with the token
    # <tt>"*"</tt>, and are called untagged responses.
    #
    class UntaggedResponse < Struct.new(:name, :data, :raw_data)
      ##
      # method: name
      # :call-seq: name -> string
      #
      # The uppercase response name, e.g. "FLAGS", "LIST", "FETCH", etc.

      ##
      # method: data
      # :call-seq: data -> object or nil
      #
      # The parsed response data, e.g: an array of flag symbols, an array of
      # capabilities strings, a ResponseText object, a MailboxList object, a
      # FetchData object, a Namespaces object, etc.  The response #name
      # determines what form the data can take.

      ##
      # method: raw_data
      # :call-seq: raw_data -> string
      #
      # The raw response data.
    end

    # Net::IMAP::IgnoredResponse represents intentionally ignored responses.
    #
    # This includes untagged response "NOOP" sent by eg. Zimbra to avoid some
    # clients to close the connection.
    #
    # It matches no IMAP standard.
    #
    class IgnoredResponse < Struct.new(:raw_data)
      ##
      # method: raw_data
      # :call-seq: raw_data -> string
      #
      # The raw response data.
    end

    # Net::IMAP::TaggedResponse represents tagged responses.
    #
    # The server completion result response indicates the success or
    # failure of the operation.  It is tagged with the same tag as the
    # client command which began the operation.
    #
    class TaggedResponse < Struct.new(:tag, :name, :data, :raw_data)
      ##
      # method: tag
      # :call-seq: tag -> string
      #
      # Returns the command tag

      ##
      # method: name
      # :call-seq: name -> string
      #
      # Returns the name, one of "OK", "NO", or "BAD".

      ##
      # method: data
      # :call-seq: data -> ResponseText
      #
      # Returns a ResponseText object

      ##
      # method: raw_data
      # :call-seq: raw_data -> string
      #
      # The raw response data.
    end

    # Net::IMAP::ResponseText represents texts of responses.
    #
    # The text may be prefixed by a ResponseCode.
    #
    # ResponseText is returned from TaggedResponse#data, or from
    # UntaggedResponse#data when the response type is a "condition" ("OK", "NO",
    # "BAD", "PREAUTH", or "BYE").
    class ResponseText < Struct.new(:code, :text)
      ##
      # method: code
      # :call-seq: code -> ResponseCode or nil
      #
      # Returns a ResponseCode, if the response contains one

      ##
      # method: text
      # :call-seq: text -> string
      #
      # Returns the response text, not including any response code
    end

    # Net::IMAP::ResponseCode represents response codes.  Response codes can be
    # retrieved from ResponseText#code and can be included in any "condition"
    # response: any TaggedResponse and UntaggedResponse when the response type
    # is a "condition" ("OK", "NO", "BAD", "PREAUTH", or "BYE").
    #
    # Some response codes come with additional data which will be parsed by
    # Net::IMAP.  Others return +nil+ for #data, but are used as a
    # machine-readable annotation for the human-readable ResponseText#text in
    # the same response.  When Net::IMAP does not know how to parse response
    # code text, #data returns the unparsed string.
    #
    # Untagged response code #data is pushed directly onto Net::IMAP#responses,
    # keyed by #name, unless it is removed by the command that generated it.
    # Use Net::IMAP#add_response_handler to view tagged response codes for
    # command methods that do not return their TaggedResponse.
    #
    # \IMAP extensions may define new codes and the data that comes with them.
    # The IANA {IMAP Response
    # Codes}[https://www.iana.org/assignments/imap-response-codes/imap-response-codes.xhtml]
    # registry has links to specifications for all standard response codes.
    # Response codes are backwards compatible:  Servers are allowed to send new
    # response codes even if the client has not enabled the extension that
    # defines them.  When unknown response code data is encountered, #data
    # will return an unparsed string.
    #
    # See [IMAP4rev1[https://www.rfc-editor.org/rfc/rfc3501]] {§7.1, "Server
    # Responses - Status
    # Responses"}[https://www.rfc-editor.org/rfc/rfc3501#section-7.1] for full
    # definitions of the basic set of IMAP4rev1 response codes:
    # * +ALERT+, the ResponseText#text contains a special alert that MUST be
    #   brought to the user's attention.
    # * +BADCHARSET+, #data will be an array of charset strings, or +nil+.
    # * +CAPABILITY+, #data will be an array of capability strings.
    # * +PARSE+, the ResponseText#text presents an error parsing a message's
    #   \[RFC5322] or [MIME-IMB] headers.
    # * +PERMANENTFLAGS+, followed by an array of flags.  System flags will be
    #   symbols, and keyword flags will be strings.  See
    #   rdoc-ref:Net::IMAP@System+flags
    # * +READ-ONLY+, the mailbox was selected read-only, or changed to read-only
    # * +READ-WRITE+, the mailbox was selected read-write, or changed to
    #   read-write
    # * +TRYCREATE+, when #append or #copy fail because the target mailbox
    #   doesn't exist.
    # * +UIDNEXT+, #data is an Integer, the next UID value of the mailbox.  See
    #   [{IMAP4rev1}[https://www.rfc-editor.org/rfc/rfc3501]],
    #   {§2.3.1.1, "Unique Identifier (UID) Message
    #   Attribute}[https://www.rfc-editor.org/rfc/rfc3501#section-2.3.1.1].
    # * +UIDVALIDITY+, #data is an Integer, the UID validity value of the
    #   mailbox  See [{IMAP4rev1}[https://www.rfc-editor.org/rfc/rfc3501]],
    #   {§2.3.1.1, "Unique Identifier (UID) Message
    #   Attribute}[https://www.rfc-editor.org/rfc/rfc3501#section-2.3.1.1].
    # * +UNSEEN+, #data is an Integer, the number of messages which do not have
    #   the <tt>\Seen</tt> flag set.
    #
    # See RFC5530[https://www.rfc-editor.org/rfc/rfc5530], "IMAP Response
    # Codes" for the definition of the following response codes, which are all
    # machine-readable annotations for the human-readable ResponseText#text, and
    # have +nil+ #data of their own:
    # * +UNAVAILABLE+
    # * +AUTHENTICATIONFAILED+
    # * +AUTHORIZATIONFAILED+
    # * +EXPIRED+
    # * +PRIVACYREQUIRED+
    # * +CONTACTADMIN+
    # * +NOPERM+
    # * +INUSE+
    # * +EXPUNGEISSUED+
    # * +CORRUPTION+
    # * +SERVERBUG+
    # * +CLIENTBUG+
    # * +CANNOT+
    # * +LIMIT+
    # * +OVERQUOTA+
    # * +ALREADYEXISTS+
    # * +NONEXISTENT+
    #
    class ResponseCode < Struct.new(:name, :data)
      ##
      # method: name
      # :call-seq: name -> string
      #
      # Returns the response code name, such as "ALERT", "PERMANENTFLAGS", or
      # "UIDVALIDITY".

      ##
      # method: data
      # :call-seq: data -> object or nil
      #
      # Returns the parsed response code data, e.g: an array of capabilities
      # strings, an array of character set strings, a list of permanent flags,
      # an Integer, etc.  The response #code determines what form the response
      # code data can take.
    end

    # Net::IMAP::UIDPlusData represents the ResponseCode#data that accompanies
    # the +APPENDUID+ and +COPYUID+ response codes.
    #
    # See [[UIDPLUS[https://www.rfc-editor.org/rfc/rfc4315.html]].
    #
    # ==== Capability requirement
    #
    # The +UIDPLUS+ capability[rdoc-ref:Net::IMAP#capability] must be supported.
    # A server that supports +UIDPLUS+ should send a UIDPlusData object inside
    # every TaggedResponse returned by the append[rdoc-ref:Net::IMAP#append],
    # copy[rdoc-ref:Net::IMAP#copy], move[rdoc-ref:Net::IMAP#move], {uid
    # copy}[rdoc-ref:Net::IMAP#uid_copy], and {uid
    # move}[rdoc-ref:Net::IMAP#uid_move] commands---unless the destination
    # mailbox reports +UIDNOTSTICKY+.
    #
    #--
    # TODO: support MULTIAPPEND
    #++
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

    # Net::IMAP::MailboxList represents contents of the LIST response,
    # representing a single mailbox path.
    #
    # Net::IMAP#list returns an array of MailboxList objects.
    #
    class MailboxList < Struct.new(:attr, :delim, :name)
      ##
      # method: attr
      # :call-seq: attr -> array of Symbols
      #
      # Returns the name attributes. Each name attribute is a symbol capitalized
      # by String#capitalize, such as :Noselect (not :NoSelect).  For the
      # semantics of each attribute, see:
      # * rdoc-ref:Net::IMAP@Basic+Mailbox+Attributes
      # * rdoc-ref:Net::IMAP@Mailbox+role+Attributes
      # * Net::IMAP@SPECIAL-USE
      # * The IANA {IMAP Mailbox Name Attributes
      #   registry}[https://www.iana.org/assignments/imap-mailbox-name-attributes/imap-mailbox-name-attributes.xhtml]

      ##
      # method: delim
      # :call-seq: delim -> single character string
      #
      # Returns the hierarchy delimiter for the mailbox path.

      ##
      # method: name
      # :call-seq: name -> string
      #
      # Returns the mailbox name.
    end

    # Net::IMAP::MailboxQuota represents contents of GETQUOTA response.
    # This object can also be a response to GETQUOTAROOT.  In the syntax
    # specification below, the delimiter used with the "#" construct is a
    # single space (SPACE).
    #
    # Net:IMAP#getquota returns an array of MailboxQuota objects.
    #
    # Net::IMAP#getquotaroot returns an array containing both MailboxQuotaRoot
    # and MailboxQuota objects.
    #
    class MailboxQuota < Struct.new(:mailbox, :usage, :quota)
      ##
      # method: mailbox
      # :call-seq: mailbox -> string
      #
      # The mailbox with the associated quota.

      ##
      # method: usage
      # :call-seq: usage -> Integer
      #
      # Current storage usage of the mailbox.

      ##
      # method: quota
      # :call-seq: quota -> Integer
      #
      # Quota limit imposed on the mailbox.
      #
    end

    # Net::IMAP::MailboxQuotaRoot represents part of the GETQUOTAROOT
    # response. (GETQUOTAROOT can also return Net::IMAP::MailboxQuota.)
    #
    # Net::IMAP#getquotaroot returns an array containing both MailboxQuotaRoot
    # and MailboxQuota objects.
    #
    class MailboxQuotaRoot < Struct.new(:mailbox, :quotaroots)
      ##
      # method: mailbox
      # :call-seq: mailbox -> string
      #
      # The mailbox with the associated quota.

      ##
      # method: mailbox
      # :call-seq: quotaroots -> array of strings
      #
      # Zero or more quotaroots that affect the quota on the specified mailbox.
    end

    # Net::IMAP::MailboxACLItem represents the response from GETACL.
    #
    # Net::IMAP#getacl returns an array of MailboxACLItem objects.
    #
    # ==== Required capability
    # +ACL+ - described in [ACL[https://tools.ietf.org/html/rfc4314]]
    class MailboxACLItem < Struct.new(:user, :rights, :mailbox)
      ##
      # method: mailbox
      # :call-seq: mailbox -> string
      #
      # The mailbox to which the indicated #user has the specified #rights.

      ##
      # method: user
      # :call-seq: user -> string
      #
      # Login name that has certain #rights to the #mailbox that was specified
      # with the getacl command.

      ##
      # method: rights
      # :call-seq: rights -> string
      #
      # The access rights the indicated #user has to the #mailbox.
    end

    # Net::IMAP::Namespace represents a single namespace contained inside a
    # NAMESPACE response.
    #
    # Returned by Net::IMAP#namespace, contained inside a Namespaces object.
    #
    class Namespace < Struct.new(:prefix, :delim, :extensions)
      ##
      # method: prefix
      # :call-seq: prefix -> string
      #
      # Returns the namespace prefix string.

      ##
      # method: delim
      # :call-seq: delim -> single character string or nil
      #
      # Returns a hierarchy delimiter character, if it exists.

      ##
      # method: extensions
      # :call-seq: extensions -> Hash[String, Array[String]]
      #
      # A hash of parameters mapped to arrays of strings, for extensibility.
      # Extension parameter semantics would be defined by the extension.
    end

    # Net::IMAP::Namespaces represents a +NAMESPACE+ server response, which
    # contains lists of #personal, #shared, and #other namespaces.
    #
    # Net::IMAP#namespace returns a Namespaces object.
    #
    class Namespaces < Struct.new(:personal, :other, :shared)
      ##
      # method: personal
      # :call-seq: personal -> array of Namespace
      #
      # Returns an array of Personal Namespace objects.

      ##
      # method: other
      # :call-seq: other -> array of Namespace
      #
      # Returns an array of Other Users' Namespace objects.

      ##
      # method: shared
      # :call-seq: shared -> array of Namespace
      #
      # Returns an array of Shared Namespace objects.
    end

    # Net::IMAP::StatusData represents the contents of the STATUS response.
    #
    # Net::IMAP#status returns the contents of #attr.
    class StatusData < Struct.new(:mailbox, :attr)
      ##
      # method: mailbox
      # :call-seq: mailbox -> string
      #
      # The mailbox name.

      ##
      # method: attr
      # :call-seq: attr -> Hash[String, Integer]
      #
      # A hash.  Each key is one of "MESSAGES", "RECENT", "UIDNEXT",
      # "UIDVALIDITY", "UNSEEN". Each value is a number.
    end

    # Net::IMAP::FetchData represents the contents of the FETCH response.
    #
    # ==== Fields:
    #
    # seqno:: Returns the message sequence number.
    #         (Note: not the unique identifier, even for the UID command response.)
    #
    # attr:: Returns a hash. Each key is a data item name, and each value is
    #        its value.
    #
    #        The current data items are:
    #
    #        [BODY]
    #           A form of BODYSTRUCTURE without extension data.
    #        [BODY[<section>]<<origin_octet>>]
    #           A string expressing the body contents of the specified section.
    #        [BODYSTRUCTURE]
    #           An object that describes the [MIME-IMB] body structure of a message.
    #           See Net::IMAP::BodyTypeBasic, Net::IMAP::BodyTypeText,
    #           Net::IMAP::BodyTypeMessage, Net::IMAP::BodyTypeMultipart.
    #        [ENVELOPE]
    #           A Net::IMAP::Envelope object that describes the envelope
    #           structure of a message.
    #        [FLAGS]
    #           A array of flag symbols that are set for this message. Flag symbols
    #           are capitalized by String#capitalize.
    #        [INTERNALDATE]
    #           A string representing the internal date of the message.
    #        [RFC822]
    #           Equivalent to +BODY[]+.
    #        [RFC822.HEADER]
    #           Equivalent to +BODY.PEEK[HEADER]+.
    #        [RFC822.SIZE]
    #           A number expressing the [RFC-822] size of the message.
    #        [RFC822.TEXT]
    #           Equivalent to +BODY[TEXT]+.
    #        [UID]
    #           A number expressing the unique identifier of the message.
    #
    # See {[IMAP4rev1] §7.4.2}[https://www.rfc-editor.org/rfc/rfc3501.html#section-7.4.2]
    # and {[IMAP4rev2] §7.5.2}[https://www.rfc-editor.org/rfc/rfc9051.html#section-7.5.2]
    # for full description of the standard fetch response data items, and
    # Net::IMAP@Message+envelope+and+body+structure for other relevant RFCs.
    #
    class FetchData < Struct.new(:seqno, :attr)
    end

    # Net::IMAP::Envelope represents envelope structures of messages.
    #
    # ==== Fields:
    #
    # date:: Returns a string that represents the date.
    #
    # subject:: Returns a string that represents the subject.
    #
    # from:: Returns an array of Net::IMAP::Address that represents the from.
    #
    # sender:: Returns an array of Net::IMAP::Address that represents the sender.
    #
    # reply_to:: Returns an array of Net::IMAP::Address that represents the reply-to.
    #
    # to:: Returns an array of Net::IMAP::Address that represents the to.
    #
    # cc:: Returns an array of Net::IMAP::Address that represents the cc.
    #
    # bcc:: Returns an array of Net::IMAP::Address that represents the bcc.
    #
    # in_reply_to:: Returns a string that represents the in-reply-to.
    #
    # message_id:: Returns a string that represents the message-id.
    #
    # See [{IMAP4rev1 §7.4.2}[https://www.rfc-editor.org/rfc/rfc3501.html#section-7.4.2]]
    # and [{IMAP4rev2 §7.5.2}[https://www.rfc-editor.org/rfc/rfc9051.html#section-7.5.2]]
    # for full description of the envelope fields, and
    # Net::IMAP@Message+envelope+and+body+structure for other relevant RFCs.
    #
    class Envelope < Struct.new(:date, :subject, :from, :sender, :reply_to,
                                :to, :cc, :bcc, :in_reply_to, :message_id)
    end

    #
    # Net::IMAP::Address represents electronic mail addresses.
    #
    # ==== Fields:
    #
    # name:: Returns the phrase from [RFC-822] mailbox.
    #
    # route:: Returns the route from [RFC-822] route-addr.
    #
    # mailbox:: nil indicates end of [RFC-822] group.
    #           If non-nil and host is nil, returns [RFC-822] group name.
    #           Otherwise, returns [RFC-822] local-part.
    #
    # host:: nil indicates [RFC-822] group syntax.
    #        Otherwise, returns [RFC-822] domain name.
    #
    class Address < Struct.new(:name, :route, :mailbox, :host)
    end

    #
    # Net::IMAP::ContentDisposition represents Content-Disposition fields.
    #
    # ==== Fields:
    #
    # dsp_type:: Returns the disposition type.
    #
    # param:: Returns a hash that represents parameters of the Content-Disposition
    #         field.
    #
    class ContentDisposition < Struct.new(:dsp_type, :param)
    end

    # Net::IMAP::ThreadMember represents a thread-node returned
    # by Net::IMAP#thread.
    #
    # ==== Fields:
    #
    # seqno:: The sequence number of this message.
    #
    # children:: An array of Net::IMAP::ThreadMember objects for mail
    #            items that are children of this in the thread.
    #
    class ThreadMember < Struct.new(:seqno, :children)
    end

    # Net::IMAP::BodyTypeBasic represents basic body structures of messages.
    #
    # ==== Fields:
    #
    # media_type:: Returns the content media type name as defined in [MIME-IMB].
    #
    # subtype:: Returns the content subtype name as defined in [MIME-IMB].
    #
    # param:: Returns a hash that represents parameters as defined in [MIME-IMB].
    #
    # content_id:: Returns a string giving the content id as defined in [MIME-IMB].
    #
    # description:: Returns a string giving the content description as defined in
    #               [MIME-IMB].
    #
    # encoding:: Returns a string giving the content transfer encoding as defined in
    #            [MIME-IMB].
    #
    # size:: Returns a number giving the size of the body in octets.
    #
    # md5:: Returns a string giving the body MD5 value as defined in [MD5].
    #
    # disposition:: Returns a Net::IMAP::ContentDisposition object giving
    #               the content disposition.
    #
    # language:: Returns a string or an array of strings giving the body
    #            language value as defined in [LANGUAGE-TAGS].
    #
    # extension:: Returns extension data.
    #
    # multipart?:: Returns false.
    #
    # See {[IMAP4rev1] §7.4.2}[https://www.rfc-editor.org/rfc/rfc3501.html#section-7.4.2]
    # and {[IMAP4rev2] §7.5.2}[https://www.rfc-editor.org/rfc/rfc9051.html#section-7.5.2-4.9]
    # for full description of all +BODYSTRUCTURE+ fields, and also
    # Net::IMAP@Message+envelope+and+body+structure for other relevant RFCs.
    #
    class BodyTypeBasic < Struct.new(:media_type, :subtype,
                                     :param, :content_id,
                                     :description, :encoding, :size,
                                     :md5, :disposition, :language,
                                     :extension)
      def multipart?
        return false
      end

      # Obsolete: use +subtype+ instead.  Calling this will
      # generate a warning message to +stderr+, then return
      # the value of +subtype+.
      def media_subtype
        warn("media_subtype is obsolete, use subtype instead.\n", uplevel: 1)
        return subtype
      end
    end

    # Net::IMAP::BodyTypeText represents TEXT body structures of messages.
    #
    # ==== Fields:
    #
    # lines:: Returns the size of the body in text lines.
    #
    # And Net::IMAP::BodyTypeText has all fields of Net::IMAP::BodyTypeBasic.
    #
    class BodyTypeText < Struct.new(:media_type, :subtype,
                                    :param, :content_id,
                                    :description, :encoding, :size,
                                    :lines,
                                    :md5, :disposition, :language,
                                    :extension)
      def multipart?
        return false
      end

      # Obsolete: use +subtype+ instead.  Calling this will
      # generate a warning message to +stderr+, then return
      # the value of +subtype+.
      def media_subtype
        warn("media_subtype is obsolete, use subtype instead.\n", uplevel: 1)
        return subtype
      end
    end

    # Net::IMAP::BodyTypeMessage represents MESSAGE/RFC822 body structures of messages.
    #
    # ==== Fields:
    #
    # envelope:: Returns a Net::IMAP::Envelope giving the envelope structure.
    #
    # body:: Returns an object giving the body structure.
    #
    # And Net::IMAP::BodyTypeMessage has all methods of Net::IMAP::BodyTypeText.
    #
    class BodyTypeMessage < Struct.new(:media_type, :subtype,
                                       :param, :content_id,
                                       :description, :encoding, :size,
                                       :envelope, :body, :lines,
                                       :md5, :disposition, :language,
                                       :extension)
      def multipart?
        return false
      end

      # Obsolete: use +subtype+ instead.  Calling this will
      # generate a warning message to +stderr+, then return
      # the value of +subtype+.
      def media_subtype
        warn("media_subtype is obsolete, use subtype instead.\n", uplevel: 1)
        return subtype
      end
    end

    # Net::IMAP::BodyTypeAttachment represents attachment body structures
    # of messages.
    #
    # ==== Fields:
    #
    # media_type:: Returns the content media type name.
    #
    # subtype:: Returns +nil+.
    #
    # param:: Returns a hash that represents parameters.
    #
    # multipart?:: Returns false.
    #
    class BodyTypeAttachment < Struct.new(:media_type, :subtype,
                                          :param)
      def multipart?
        return false
      end
    end

    # Net::IMAP::BodyTypeMultipart represents multipart body structures
    # of messages.
    #
    # ==== Fields:
    #
    # media_type:: Returns the content media type name as defined in [MIME-IMB].
    #
    # subtype:: Returns the content subtype name as defined in [MIME-IMB].
    #
    # parts:: Returns multiple parts.
    #
    # param:: Returns a hash that represents parameters as defined in [MIME-IMB].
    #
    # disposition:: Returns a Net::IMAP::ContentDisposition object giving
    #               the content disposition.
    #
    # language:: Returns a string or an array of strings giving the body
    #            language value as defined in [LANGUAGE-TAGS].
    #
    # extension:: Returns extension data.
    #
    # multipart?:: Returns true.
    #
    class BodyTypeMultipart < Struct.new(:media_type, :subtype,
                                         :parts,
                                         :param, :disposition, :language,
                                         :extension)
      def multipart?
        return true
      end

      # Obsolete: use +subtype+ instead.  Calling this will
      # generate a warning message to +stderr+, then return
      # the value of +subtype+.
      def media_subtype
        warn("media_subtype is obsolete, use subtype instead.\n", uplevel: 1)
        return subtype
      end
    end

    class BodyTypeExtension < Struct.new(:media_type, :subtype,
                                         :params, :content_id,
                                         :description, :encoding, :size)
      def multipart?
        return false
      end
    end

  end
end
