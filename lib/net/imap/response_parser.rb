# frozen_string_literal: true

require_relative "errors"
require_relative "response_parser/parser_utils"

module Net
  class IMAP < Protocol

    # Parses an \IMAP server response.
    class ResponseParser
      include ParserUtils
      extend  ParserUtils::Generator

      # :call-seq: Net::IMAP::ResponseParser.new -> Net::IMAP::ResponseParser
      def initialize
        @str = nil
        @pos = nil
        @lex_state = nil
        @token = nil
      end

      # :call-seq:
      #   parse(str) -> ContinuationRequest
      #   parse(str) -> UntaggedResponse
      #   parse(str) -> TaggedResponse
      #
      # Raises ResponseParseError for unparsable strings.
      def parse(str)
        @str = str
        @pos = 0
        @lex_state = EXPR_BEG
        @token = nil
        return response
      end

      private

      # :stopdoc:

      EXPR_BEG   = :EXPR_BEG     # the default, used in most places
      EXPR_DATA  = :EXPR_DATA    # envelope, body(structure), namespaces

      T_SPACE    = :SPACE        # atom special
      T_ATOM     = :ATOM         # atom (subset of astring chars)
      T_NIL      = :NIL          # subset of atom and label
      T_NUMBER   = :NUMBER       # subset of atom
      T_LBRA     = :LBRA         # subset of atom
      T_PLUS     = :PLUS         # subset of atom; tag special
      T_RBRA     = :RBRA         # atom special; resp_special; valid astring char
      T_QUOTED   = :QUOTED       # starts/end with atom special
      T_BSLASH   = :BSLASH       # atom special; quoted special
      T_LPAR     = :LPAR         # atom special; paren list delimiter
      T_RPAR     = :RPAR         # atom special; paren list delimiter
      T_STAR     = :STAR         # atom special; list wildcard
      T_PERCENT  = :PERCENT      # atom special; list wildcard
      T_LITERAL  = :LITERAL      # starts with atom special
      T_CRLF     = :CRLF         # atom special; text special; quoted special
      T_TEXT     = :TEXT         # any char except CRLF
      T_EOF      = :EOF          # end of response string

      module Patterns

        module CharClassSubtraction
          refine Regexp do
            def -(rhs); /[#{source}&&[^#{rhs.source}]]/n.freeze end
          end
        end
        using CharClassSubtraction

        # From RFC5234, "Augmented BNF for Syntax Specifications: ABNF"
        # >>>
        #   ALPHA   =  %x41-5A / %x61-7A   ; A-Z / a-z
        #   CHAR    = %x01-7F
        #   CRLF    =  CR LF
        #                   ; Internet standard newline
        #   CTL     = %x00-1F / %x7F
        #                ; controls
        #   DIGIT   =  %x30-39
        #                   ; 0-9
        #   DQUOTE  =  %x22
        #                   ; " (Double Quote)
        #   HEXDIG  =  DIGIT / "A" / "B" / "C" / "D" / "E" / "F"
        #   OCTET   = %x00-FF
        #   SP      =  %x20
        module RFC5234
          ALPHA     = /[A-Za-z]/n
          CHAR      = /[\x01-\x7f]/n
          CRLF      = /\r\n/n
          CTL       = /[\x00-\x1F\x7F]/n
          DIGIT     = /\d/n
          DQUOTE    = /"/n
          HEXDIG    = /\h/
          OCTET     = /[\x00-\xFF]/n # not using /./m for embedding purposes
          SP        = / /n
        end

        # UTF-8, a transformation format of ISO 10646
        # >>>
        #   UTF8-1      = %x00-7F
        #   UTF8-tail   = %x80-BF
        #   UTF8-2      = %xC2-DF UTF8-tail
        #   UTF8-3      = %xE0 %xA0-BF UTF8-tail / %xE1-EC 2( UTF8-tail ) /
        #                 %xED %x80-9F UTF8-tail / %xEE-EF 2( UTF8-tail )
        #   UTF8-4      = %xF0 %x90-BF 2( UTF8-tail ) / %xF1-F3 3( UTF8-tail ) /
        #                 %xF4 %x80-8F 2( UTF8-tail )
        #   UTF8-char   = UTF8-1 / UTF8-2 / UTF8-3 / UTF8-4
        #   UTF8-octets = *( UTF8-char )
        #
        # n.b. String * Integer is used for repetition, rather than /x{3}/,
        # because ruby 3.2's linear-time cache-based optimization doesn't work
        # with "bounded or fixed times repetition nesting in another repetition
        # (e.g. /(a{2,3})*/). It is an implementation issue entirely, but we
        # believe it is hard to support this case correctly."
        # See https://bugs.ruby-lang.org/issues/19104
        module RFC3629
          UTF8_1      = /[\x00-\x7f]/n # aka ASCII 7bit
          UTF8_TAIL   = /[\x80-\xBF]/n
          UTF8_2      = /[\xC2-\xDF]#{UTF8_TAIL}/n
          UTF8_3      = Regexp.union(/\xE0[\xA0-\xBF]#{UTF8_TAIL}/n,
                                     /\xED[\x80-\x9F]#{UTF8_TAIL}/n,
                                     /[\xE1-\xEC]#{    UTF8_TAIL.source * 2}/n,
                                     /[\xEE-\xEF]#{    UTF8_TAIL.source * 2}/n)
          UTF8_4      = Regexp.union(/[\xF1-\xF3]#{    UTF8_TAIL.source * 3}/n,
                                     /\xF0[\x90-\xBF]#{UTF8_TAIL.source * 2}/n,
                                     /\xF4[\x80-\x8F]#{UTF8_TAIL.source * 2}/n)
          UTF8_CHAR   = Regexp.union(UTF8_1, UTF8_2, UTF8_3, UTF8_4)
          UTF8_OCTETS = /#{UTF8_CHAR}*/n
        end

        include RFC5234
        include RFC3629

        # quoted-specials = DQUOTE / "\"
        QUOTED_SPECIALS   = /["\\]/n
        # resp-specials   = "]"
        RESP_SPECIALS     = /[\]]/n

        # TEXT-CHAR       = <any CHAR except CR and LF>
        TEXT_CHAR         = CHAR - /[\r\n]/

        # resp-text-code  = ... / atom [SP 1*<any TEXT-CHAR except "]">]
        CODE_TEXT_CHAR    = TEXT_CHAR - RESP_SPECIALS
        CODE_TEXT         = /#{CODE_TEXT_CHAR}+/n

        # RFC3501:
        #   QUOTED-CHAR   = <any TEXT-CHAR except quoted-specials> /
        #                   "\" quoted-specials
        # RFC9051:
        #   QUOTED-CHAR   = <any TEXT-CHAR except quoted-specials> /
        #                   "\" quoted-specials / UTF8-2 / UTF8-3 / UTF8-4
        # RFC3501 & RFC9051:
        #   quoted          = DQUOTE *QUOTED-CHAR DQUOTE
        QUOTED_CHAR_safe  = TEXT_CHAR - QUOTED_SPECIALS
        QUOTED_CHAR_esc   = /\\#{QUOTED_SPECIALS}/n
        QUOTED_CHAR_rev1  = Regexp.union(QUOTED_CHAR_safe, QUOTED_CHAR_esc)
        QUOTED_CHAR_rev2  = Regexp.union(QUOTED_CHAR_rev1,
                                         UTF8_2, UTF8_3, UTF8_4)
        QUOTED_rev1       = /"(#{QUOTED_CHAR_rev1}*)"/n
        QUOTED_rev2       = /"(#{QUOTED_CHAR_rev2}*)"/n

        # RFC3501:
        #   text          = 1*TEXT-CHAR
        # RFC9051:
        #   text          = 1*(TEXT-CHAR / UTF8-2 / UTF8-3 / UTF8-4)
        #                     ; Non-ASCII text can only be returned
        #                     ; after ENABLE IMAP4rev2 command
        TEXT_rev1         = /#{TEXT_CHAR}+/
        TEXT_rev2         = /#{Regexp.union TEXT_CHAR, UTF8_2, UTF8_3, UTF8_4}+/

        module_function

        def unescape_quoted!(quoted)
          quoted
            &.gsub!(/\\(#{QUOTED_SPECIALS})/n, "\\1")
            &.force_encoding("UTF-8")
        end

        def unescape_quoted(quoted)
          quoted
            &.gsub(/\\(#{QUOTED_SPECIALS})/n, "\\1")
            &.force_encoding("UTF-8")
        end

      end

      # the default, used in most places
      BEG_REGEXP = /\G(?:\
(?# 1:  SPACE   )( +)|\
(?# 2:  NIL     )(NIL)(?=[\x80-\xff(){ \x00-\x1f\x7f%*"\\\[\]+])|\
(?# 3:  NUMBER  )(\d+)(?=[\x80-\xff(){ \x00-\x1f\x7f%*"\\\[\]+])|\
(?# 4:  ATOM    )([^\x80-\xff(){ \x00-\x1f\x7f%*"\\\[\]+]+)|\
(?# 5:  QUOTED  )#{Patterns::QUOTED_rev2}|\
(?# 6:  LPAR    )(\()|\
(?# 7:  RPAR    )(\))|\
(?# 8:  BSLASH  )(\\)|\
(?# 9:  STAR    )(\*)|\
(?# 10: LBRA    )(\[)|\
(?# 11: RBRA    )(\])|\
(?# 12: LITERAL )\{(\d+)\}\r\n|\
(?# 13: PLUS    )(\+)|\
(?# 14: PERCENT )(%)|\
(?# 15: CRLF    )(\r\n)|\
(?# 16: EOF     )(\z))/ni

      # envelope, body(structure), namespaces
      DATA_REGEXP = /\G(?:\
(?# 1:  SPACE   )( )|\
(?# 2:  NIL     )(NIL)|\
(?# 3:  NUMBER  )(\d+)|\
(?# 4:  QUOTED  )#{Patterns::QUOTED_rev2}|\
(?# 5:  LITERAL )\{(\d+)\}\r\n|\
(?# 6:  LPAR    )(\()|\
(?# 7:  RPAR    )(\)))/ni

      # text, after 'resp-text-code "]"'
      TEXT_REGEXP = /\G(#{Patterns::TEXT_rev2})/n

      # resp-text-code, after 'atom SP'
      CTEXT_REGEXP = /\G(#{Patterns::CODE_TEXT})/n

      Token = Struct.new(:symbol, :value)

      def_char_matchers :SP,   " ", :T_SPACE

      def_char_matchers :lbra, "[", :T_LBRA
      def_char_matchers :rbra, "]", :T_RBRA

      # atom            = 1*ATOM-CHAR
      #
      # TODO: match atom entirely by regexp (in the "lexer")
      def atom; -combine_adjacent(*ATOM_TOKENS) end

      # the #accept version of #atom
      def atom?; -combine_adjacent(*ATOM_TOKENS) if lookahead?(*ATOM_TOKENS) end

      # Returns <tt>atom.upcase</tt>
      def case_insensitive__atom; -combine_adjacent(*ATOM_TOKENS).upcase end

      # Returns <tt>atom?&.upcase</tt>
      def case_insensitive__atom?
        -combine_adjacent(*ATOM_TOKENS).upcase if lookahead?(*ATOM_TOKENS)
      end

      # In addition to explicitly uses of +tagged-ext-label+, use this to match
      # keywords when the grammar has not provided any extension syntax.
      #
      # Do *not* use this for labels where the grammar specifies extensions
      # can be +atom+, even if all currently defined labels would match.  For
      # example response codes in +resp-text-code+.
      #
      #   tagged-ext-label    = tagged-label-fchar *tagged-label-char
      #                         ; Is a valid RFC 3501 "atom".
      #   tagged-label-fchar  = ALPHA / "-" / "_" / "."
      #   tagged-label-char   = tagged-label-fchar / DIGIT / ":"
      #
      # TODO: add to lexer and only match tagged-ext-label
      alias tagged_ext_label  case_insensitive__atom
      alias tagged_ext_label? case_insensitive__atom?

      # Use #label or #label_in to assert specific known labels
      # (+tagged-ext-label+ only, not +atom+).
      def label(word)
        (val = tagged_ext_label) == word and return val
        parse_error("unexpected atom %p, expected %p instead", val, word)
      end

      def response
        token = lookahead
        case token.symbol
        when T_PLUS
          result = continue_req
        when T_STAR
          result = response_untagged
        else
          result = response_tagged
        end
        while lookahead.symbol == T_SPACE
          # Ignore trailing space for Microsoft Exchange Server
          shift_token
        end
        match(T_CRLF)
        match(T_EOF)
        return result
      end

      def continue_req
        match(T_PLUS)
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
          return ContinuationRequest.new(resp_text, @str)
        else
          return ContinuationRequest.new(ResponseText.new(nil, ""), @str)
        end
      end

      def response_untagged
        match(T_STAR)
        match(T_SPACE)
        token = lookahead
        if token.symbol == T_NUMBER
          return numeric_response
        elsif token.symbol == T_ATOM
          case token.value
          when /\A(?:OK|NO|BAD|BYE|PREAUTH)\z/ni
            return response_cond
          when /\A(?:FLAGS)\z/ni
            return flags_response
          when /\A(?:ID)\z/ni
            return id_response
          when /\A(?:LIST|LSUB|XLIST)\z/ni
            return list_response
          when /\A(?:NAMESPACE)\z/ni
            return namespace_response
          when /\A(?:QUOTA)\z/ni
            return getquota_response
          when /\A(?:QUOTAROOT)\z/ni
            return getquotaroot_response
          when /\A(?:ACL)\z/ni
            return getacl_response
          when /\A(?:SEARCH|SORT)\z/ni
            return search_response
          when /\A(?:THREAD)\z/ni
            return thread_response
          when /\A(?:STATUS)\z/ni
            return status_response
          when /\A(?:CAPABILITY)\z/ni
            return capability_data__untagged
          when /\A(?:NOOP)\z/ni
            return ignored_response
          when /\A(?:ENABLED)\z/ni
            return enable_data
          else
            return text_response
          end
        else
          parse_error("unexpected token %s", token.symbol)
        end
      end

      def response_tagged
        tag = astring_chars
        match(T_SPACE)
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return TaggedResponse.new(tag, name, resp_text, @str)
      end

      def response_cond
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return UntaggedResponse.new(name, resp_text, @str)
      end

      def numeric_response
        n = number
        match(T_SPACE)
        token = match(T_ATOM)
        name = token.value.upcase
        case name
        when "EXISTS", "RECENT", "EXPUNGE"
          return UntaggedResponse.new(name, n, @str)
        when "FETCH"
          shift_token
          match(T_SPACE)
          data = FetchData.new(n, msg_att(n))
          return UntaggedResponse.new(name, data, @str)
        end
      end

      def msg_att(n)
        match(T_LPAR)
        attr = {}
        while true
          token = lookahead
          case token.symbol
          when T_RPAR
            shift_token
            break
          when T_SPACE
            shift_token
            next
          end
          case token.value
          when /\A(?:ENVELOPE)\z/ni
            name, val = envelope_data
          when /\A(?:FLAGS)\z/ni
            name, val = flags_data
          when /\A(?:INTERNALDATE)\z/ni
            name, val = internaldate_data
          when /\A(?:RFC822(?:\.HEADER|\.TEXT)?)\z/ni
            name, val = rfc822_text
          when /\A(?:RFC822\.SIZE)\z/ni
            name, val = rfc822_size
          when /\A(?:BODY(?:STRUCTURE)?)\z/ni
            name, val = body_data
          when /\A(?:UID)\z/ni
            name, val = uid_data
          when /\A(?:MODSEQ)\z/ni
            name, val = modseq_data
          else
            parse_error("unknown attribute `%s' for {%d}", token.value, n)
          end
          attr[name] = val
        end
        return attr
      end

      def envelope_data
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return name, envelope
      end

      def envelope
        @lex_state = EXPR_DATA
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          result = nil
        else
          match(T_LPAR)
          date = nstring
          match(T_SPACE)
          subject = nstring
          match(T_SPACE)
          from = address_list
          match(T_SPACE)
          sender = address_list
          match(T_SPACE)
          reply_to = address_list
          match(T_SPACE)
          to = address_list
          match(T_SPACE)
          cc = address_list
          match(T_SPACE)
          bcc = address_list
          match(T_SPACE)
          in_reply_to = nstring
          match(T_SPACE)
          message_id = nstring
          match(T_RPAR)
          result = Envelope.new(date, subject, from, sender, reply_to,
                                to, cc, bcc, in_reply_to, message_id)
        end
        @lex_state = EXPR_BEG
        return result
      end

      def flags_data
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return name, flag_list
      end

      def internaldate_data
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        token = match(T_QUOTED)
        return name, token.value
      end

      def rfc822_text
        token = match(T_ATOM)
        name = token.value.upcase
        token = lookahead
        if token.symbol == T_LBRA
          shift_token
          match(T_RBRA)
        end
        match(T_SPACE)
        return name, nstring
      end

      def rfc822_size
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return name, number
      end

      def body_data
        token = match(T_ATOM)
        name = token.value.upcase
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
          return name, body
        end
        name.concat(section)
        token = lookahead
        if token.symbol == T_ATOM
          name.concat(token.value)
          shift_token
        end
        match(T_SPACE)
        data = nstring
        return name, data
      end

      def body
        @lex_state = EXPR_DATA
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          result = nil
        else
          match(T_LPAR)
          token = lookahead
          if token.symbol == T_LPAR
            result = body_type_mpart
          else
            result = body_type_1part
          end
          match(T_RPAR)
        end
        @lex_state = EXPR_BEG
        return result
      end

      def body_type_1part
        token = lookahead
        case token.value
        when /\A(?:TEXT)\z/ni
          return body_type_text
        when /\A(?:MESSAGE)\z/ni
          return body_type_msg
        when /\A(?:ATTACHMENT)\z/ni
          return body_type_attachment
        when /\A(?:MIXED)\z/ni
          return body_type_mixed
        else
          return body_type_basic
        end
      end

      def body_type_basic
        mtype, msubtype = media_type
        token = lookahead
        if token.symbol == T_RPAR
          return BodyTypeBasic.new(mtype, msubtype)
        end
        match(T_SPACE)
        param, content_id, desc, enc, size = body_fields
        md5, disposition, language, extension = body_ext_1part
        return BodyTypeBasic.new(mtype, msubtype,
                                 param, content_id,
                                 desc, enc, size,
                                 md5, disposition, language, extension)
      end

      def body_type_text
        mtype, msubtype = media_type
        match(T_SPACE)
        param, content_id, desc, enc, size = body_fields
        match(T_SPACE)
        lines = number
        md5, disposition, language, extension = body_ext_1part
        return BodyTypeText.new(mtype, msubtype,
                                param, content_id,
                                desc, enc, size,
                                lines,
                                md5, disposition, language, extension)
      end

      def body_type_msg
        mtype, msubtype = media_type
        match(T_SPACE)
        param, content_id, desc, enc, size = body_fields

        token = lookahead
        if token.symbol == T_RPAR
          # If this is not message/rfc822, we shouldn't apply the RFC822
          # spec to it.  We should handle anything other than
          # message/rfc822 using multipart extension data [rfc3501] (i.e.
          # the data itself won't be returned, we would have to retrieve it
          # with BODYSTRUCTURE instead of with BODY

          # Also, sometimes a message/rfc822 is included as a large
          # attachment instead of having all of the other details
          # (e.g. attaching a .eml file to an email)
          if msubtype == "RFC822"
            return BodyTypeMessage.new(mtype, msubtype, param, content_id,
                                       desc, enc, size, nil, nil, nil, nil,
                                       nil, nil, nil)
          else
            return BodyTypeExtension.new(mtype, msubtype,
                                         param, content_id,
                                         desc, enc, size)
          end
        end

        match(T_SPACE)
        env = envelope
        match(T_SPACE)
        b = body
        match(T_SPACE)
        lines = number
        md5, disposition, language, extension = body_ext_1part
        return BodyTypeMessage.new(mtype, msubtype,
                                   param, content_id,
                                   desc, enc, size,
                                   env, b, lines,
                                   md5, disposition, language, extension)
      end

      def body_type_attachment
        mtype = case_insensitive_string
        match(T_SPACE)
        param = body_fld_param
        return BodyTypeAttachment.new(mtype, nil, param)
      end

      def body_type_mixed
        mtype = "MULTIPART"
        msubtype = case_insensitive_string
        param, disposition, language, extension = body_ext_mpart
        return BodyTypeBasic.new(mtype, msubtype, param, nil, nil, nil, nil, nil, disposition, language, extension)
      end

      def body_type_mpart
        parts = []
        while true
          token = lookahead
          if token.symbol == T_SPACE
            shift_token
            break
          end
          parts.push(body)
        end
        mtype = "MULTIPART"
        msubtype = case_insensitive_string
        param, disposition, language, extension = body_ext_mpart
        return BodyTypeMultipart.new(mtype, msubtype, parts,
                                     param, disposition, language,
                                     extension)
      end

      def media_type
        mtype = case_insensitive_string
        token = lookahead
        if token.symbol != T_SPACE
          return mtype, nil
        end
        match(T_SPACE)
        msubtype = case_insensitive_string
        return mtype, msubtype
      end

      def body_fields
        param = body_fld_param
        match(T_SPACE)
        content_id = nstring
        match(T_SPACE)
        desc = nstring
        match(T_SPACE)
        enc = case_insensitive_string
        match(T_SPACE)
        size = number
        return param, content_id, desc, enc, size
      end

      def body_fld_param
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        end
        match(T_LPAR)
        param = {}
        while true
          token = lookahead
          case token.symbol
          when T_RPAR
            shift_token
            break
          when T_SPACE
            shift_token
          end
          name = case_insensitive_string
          match(T_SPACE)
          val = string
          param[name] = val
        end
        return param
      end

      def body_ext_1part
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return nil
        end
        md5 = nstring

        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return md5
        end
        disposition = body_fld_dsp

        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return md5, disposition
        end
        language = body_fld_lang

        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return md5, disposition, language
        end

        extension = body_extensions
        return md5, disposition, language, extension
      end

      def body_ext_mpart
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return nil
        end
        param = body_fld_param

        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return param
        end
        disposition = body_fld_dsp

        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return param, disposition
        end
        language = body_fld_lang

        token = lookahead
        if token.symbol == T_SPACE
          shift_token
        else
          return param, disposition, language
        end

        extension = body_extensions
        return param, disposition, language, extension
      end

      def body_fld_dsp
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        end
        match(T_LPAR)
        dsp_type = case_insensitive_string
        match(T_SPACE)
        param = body_fld_param
        match(T_RPAR)
        return ContentDisposition.new(dsp_type, param)
      end

      def body_fld_lang
        token = lookahead
        if token.symbol == T_LPAR
          shift_token
          result = []
          while true
            token = lookahead
            case token.symbol
            when T_RPAR
              shift_token
              return result
            when T_SPACE
              shift_token
            end
            result.push(case_insensitive_string)
          end
        else
          lang = nstring
          if lang
            return lang.upcase
          else
            return lang
          end
        end
      end

      def body_extensions
        result = []
        while true
          token = lookahead
          case token.symbol
          when T_RPAR
            return result
          when T_SPACE
            shift_token
          end
          result.push(body_extension)
        end
      end

      def body_extension
        token = lookahead
        case token.symbol
        when T_LPAR
          shift_token
          result = body_extensions
          match(T_RPAR)
          return result
        when T_NUMBER
          return number
        else
          return nstring
        end
      end

      def section
        str = String.new
        token = match(T_LBRA)
        str.concat(token.value)
        token = match(T_ATOM, T_NUMBER, T_RBRA)
        if token.symbol == T_RBRA
          str.concat(token.value)
          return str
        end
        str.concat(token.value)
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
          str.concat(token.value)
          token = match(T_LPAR)
          str.concat(token.value)
          while true
            token = lookahead
            case token.symbol
            when T_RPAR
              str.concat(token.value)
              shift_token
              break
            when T_SPACE
              shift_token
              str.concat(token.value)
            end
            str.concat(format_string(astring))
          end
        end
        token = match(T_RBRA)
        str.concat(token.value)
        return str
      end

      def format_string(str)
        case str
        when ""
          return '""'
        when /[\x80-\xff\r\n]/n
          # literal
          return "{" + str.bytesize.to_s + "}" + CRLF + str
        when /[(){ \x00-\x1f\x7f%*"\\]/n
          # quoted string
          return '"' + str.gsub(/["\\]/n, "\\\\\\&") + '"'
        else
          # atom
          return str
        end
      end

      def uid_data
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return name, number
      end

      def modseq_data
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        match(T_LPAR)
        modseq = number
        match(T_RPAR)
        return name, modseq
      end

      def ignored_response
        while lookahead.symbol != T_CRLF
          shift_token
        end
        return IgnoredResponse.new(@str)
      end

      def text_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return UntaggedResponse.new(name, text)
      end

      def flags_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return UntaggedResponse.new(name, flag_list, @str)
      end

      def list_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        return UntaggedResponse.new(name, mailbox_list, @str)
      end

      def mailbox_list
        attr = flag_list
        match(T_SPACE)
        token = match(T_QUOTED, T_NIL)
        if token.symbol == T_NIL
          delim = nil
        else
          delim = token.value
        end
        match(T_SPACE)
        name = astring
        return MailboxList.new(attr, delim, name)
      end

      def getquota_response
        # If quota never established, get back
        # `NO Quota root does not exist'.
        # If quota removed, get `()' after the
        # folder spec with no mention of `STORAGE'.
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        mailbox = astring
        match(T_SPACE)
        match(T_LPAR)
        token = lookahead
        case token.symbol
        when T_RPAR
          shift_token
          data = MailboxQuota.new(mailbox, nil, nil)
          return UntaggedResponse.new(name, data, @str)
        when T_ATOM
          shift_token
          match(T_SPACE)
          token = match(T_NUMBER)
          usage = token.value
          match(T_SPACE)
          token = match(T_NUMBER)
          quota = token.value
          match(T_RPAR)
          data = MailboxQuota.new(mailbox, usage, quota)
          return UntaggedResponse.new(name, data, @str)
        else
          parse_error("unexpected token %s", token.symbol)
        end
      end

      def getquotaroot_response
        # Similar to getquota, but only admin can use getquota.
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        mailbox = astring
        quotaroots = []
        while true
          token = lookahead
          break unless token.symbol == T_SPACE
          shift_token
          quotaroots.push(astring)
        end
        data = MailboxQuotaRoot.new(mailbox, quotaroots)
        return UntaggedResponse.new(name, data, @str)
      end

      def getacl_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        mailbox = astring
        data = []
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
          while true
            token = lookahead
            case token.symbol
            when T_CRLF
              break
            when T_SPACE
              shift_token
            end
            user = astring
            match(T_SPACE)
            rights = astring
            data.push(MailboxACLItem.new(user, rights, mailbox))
          end
        end
        return UntaggedResponse.new(name, data, @str)
      end

      def search_response
        token = match(T_ATOM)
        name = token.value.upcase
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
          data = []
          while true
            token = lookahead
            case token.symbol
            when T_CRLF
              break
            when T_SPACE
              shift_token
            when T_NUMBER
              data.push(number)
            when T_LPAR
              # TODO: include the MODSEQ value in a response
              shift_token
              match(T_ATOM)
              match(T_SPACE)
              match(T_NUMBER)
              match(T_RPAR)
            end
          end
        else
          data = []
        end
        return UntaggedResponse.new(name, data, @str)
      end

      def thread_response
        token = match(T_ATOM)
        name = token.value.upcase
        token = lookahead

        if token.symbol == T_SPACE
          threads = []

          while true
            shift_token
            token = lookahead

            case token.symbol
            when T_LPAR
              threads << thread_branch(token)
            when T_CRLF
              break
            end
          end
        else
          # no member
          threads = []
        end

        return UntaggedResponse.new(name, threads, @str)
      end

      def thread_branch(token)
        rootmember = nil
        lastmember = nil

        while true
          shift_token    # ignore first T_LPAR
          token = lookahead

          case token.symbol
          when T_NUMBER
            # new member
            newmember = ThreadMember.new(number, [])
            if rootmember.nil?
              rootmember = newmember
            else
              lastmember.children << newmember
            end
            lastmember = newmember
          when T_SPACE
            # do nothing
          when T_LPAR
            if rootmember.nil?
              # dummy member
              lastmember = rootmember = ThreadMember.new(nil, [])
            end

            lastmember.children << thread_branch(token)
          when T_RPAR
            break
          end
        end

        return rootmember
      end

      def status_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        mailbox = astring
        match(T_SPACE)
        match(T_LPAR)
        attr = {}
        while true
          token = lookahead
          case token.symbol
          when T_RPAR
            shift_token
            break
          when T_SPACE
            shift_token
          end
          token = match(T_ATOM)
          key = token.value.upcase
          match(T_SPACE)
          val = number
          attr[key] = val
        end
        data = StatusData.new(mailbox, attr)
        return UntaggedResponse.new(name, data, @str)
      end

      # The presence of "IMAP4rev1" or "IMAP4rev2" is unenforced here.
      # The grammar rule is used by both response-data and resp-text-code.
      # But this method only returns UntaggedResponse (response-data).
      #
      # RFC3501:
      #   capability-data  = "CAPABILITY" *(SP capability) SP "IMAP4rev1"
      #                      *(SP capability)
      # RFC9051:
      #   capability-data  = "CAPABILITY" *(SP capability) SP "IMAP4rev2"
      #                      *(SP capability)
      def capability_data__untagged
        UntaggedResponse.new label("CAPABILITY"), capability__list, @str
      end

      # enable-data   = "ENABLED" *(SP capability)
      def enable_data
        UntaggedResponse.new label("ENABLED"), capability__list, @str
      end

      # As a workaround for buggy servers, allow a trailing SP:
      #     *(SP capapility) [SP]
      def capability__list
        data = []; while _ = SP? && capability? do data << _ end; data
      end

      # capability      = ("AUTH=" auth-type) / atom
      #                     ; New capabilities MUST begin with "X" or be
      #                     ; registered with IANA as standard or
      #                     ; standards-track
      alias capability  case_insensitive__atom
      alias capability? case_insensitive__atom?

      def id_response
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        token = match(T_LPAR, T_NIL)
        if token.symbol == T_NIL
          return UntaggedResponse.new(name, nil, @str)
        else
          data = {}
          while true
            token = lookahead
            case token.symbol
            when T_RPAR
              shift_token
              break
            when T_SPACE
              shift_token
              next
            else
              key = string
              match(T_SPACE)
              val = nstring
              data[key] = val
            end
          end
          return UntaggedResponse.new(name, data, @str)
        end
      end

      def namespace_response
        @lex_state = EXPR_DATA
        token = lookahead
        token = match(T_ATOM)
        name = token.value.upcase
        match(T_SPACE)
        personal = namespaces
        match(T_SPACE)
        other = namespaces
        match(T_SPACE)
        shared = namespaces
        @lex_state = EXPR_BEG
        data = Namespaces.new(personal, other, shared)
        return UntaggedResponse.new(name, data, @str)
      end

      def namespaces
        token = lookahead
        # empty () is not allowed, so nil is functionally identical to empty.
        data = []
        if token.symbol == T_NIL
          shift_token
        else
          match(T_LPAR)
          loop do
            data << namespace
            break unless lookahead.symbol == T_SPACE
            shift_token
          end
          match(T_RPAR)
        end
        data
      end

      def namespace
        match(T_LPAR)
        prefix = match(T_QUOTED, T_LITERAL).value
        match(T_SPACE)
        delimiter = string
        extensions = namespace_response_extensions
        match(T_RPAR)
        Namespace.new(prefix, delimiter, extensions)
      end

      def namespace_response_extensions
        data = {}
        token = lookahead
        if token.symbol == T_SPACE
          shift_token
          name = match(T_QUOTED, T_LITERAL).value
          data[name] ||= []
          match(T_SPACE)
          match(T_LPAR)
          loop do
            data[name].push match(T_QUOTED, T_LITERAL).value
            break unless lookahead.symbol == T_SPACE
            shift_token
          end
          match(T_RPAR)
        end
        data
      end

      #   TEXT-CHAR       = <any CHAR except CR and LF>
      # RFC3501:
      #   text            = 1*TEXT-CHAR
      # RFC9051:
      #   text            = 1*(TEXT-CHAR / UTF8-2 / UTF8-3 / UTF8-4)
      #                     ; Non-ASCII text can only be returned
      #                     ; after ENABLE IMAP4rev2 command
      def text
        match_re(TEXT_REGEXP, "text")[0].force_encoding("UTF-8")
      end

      # an "accept" versiun of #text
      def text?
        accept_re(TEXT_REGEXP)&.[](0)&.force_encoding("UTF-8")
      end

      # RFC3501:
      #   resp-text       = ["[" resp-text-code "]" SP] text
      # RFC9051:
      #   resp-text       = ["[" resp-text-code "]" SP] [text]
      #
      # We leniently re-interpret this as
      #   resp-text       = ["[" resp-text-code "]" [SP [text]] / [text]
      def resp_text
        if lbra?
          code = resp_text_code; rbra
          ResponseText.new(code, SP? && text? || "")
        else
          ResponseText.new(nil, text? || "")
        end
      end

      # See https://www.rfc-editor.org/errata/rfc3501
      #
      # resp-text-code  = "ALERT" /
      #                   "BADCHARSET" [SP "(" charset *(SP charset) ")" ] /
      #                   capability-data / "PARSE" /
      #                   "PERMANENTFLAGS" SP "("
      #                   [flag-perm *(SP flag-perm)] ")" /
      #                   "READ-ONLY" / "READ-WRITE" / "TRYCREATE" /
      #                   "UIDNEXT" SP nz-number / "UIDVALIDITY" SP nz-number /
      #                   "UNSEEN" SP nz-number /
      #                   atom [SP 1*<any TEXT-CHAR except "]">]
      #
      # +UIDPLUS+ ABNF:: https://www.rfc-editor.org/rfc/rfc4315.html#section-4
      #   resp-text-code  =/ resp-code-apnd / resp-code-copy / "UIDNOTSTICKY"
      def resp_text_code
        token = match(T_ATOM)
        name = token.value.upcase
        case name
        when /\A(?:ALERT|PARSE|READ-ONLY|READ-WRITE|TRYCREATE|NOMODSEQ)\z/n
          result = ResponseCode.new(name, nil)
        when /\A(?:BADCHARSET)\z/n
          result = ResponseCode.new(name, charset_list)
        when /\A(?:CAPABILITY)\z/ni
          result = ResponseCode.new(name, capability__list)
        when /\A(?:PERMANENTFLAGS)\z/n
          match(T_SPACE)
          result = ResponseCode.new(name, flag_list)
        when /\A(?:UIDVALIDITY|UIDNEXT|UNSEEN)\z/n
          match(T_SPACE)
          result = ResponseCode.new(name, number)
        when /\A(?:APPENDUID)\z/n
          result = ResponseCode.new(name, resp_code_apnd__data)
        when /\A(?:COPYUID)\z/n
          result = ResponseCode.new(name, resp_code_copy__data)
        else
          token = lookahead
          if token.symbol == T_SPACE
            shift_token
            result = ResponseCode.new(name, text_chars_except_rbra)
          else
            result = ResponseCode.new(name, nil)
          end
        end
        return result
      end

      # 1*<any TEXT-CHAR except "]">
      def text_chars_except_rbra
        match_re(CTEXT_REGEXP, '1*<any TEXT-CHAR except "]">')[0]
      end

      def charset_list
        result = []
        if accept(T_SPACE)
          match(T_LPAR)
          result << charset
          while accept(T_SPACE)
            result << charset
          end
          match(T_RPAR)
        end
        result
      end

      # already matched:  "APPENDUID"
      #
      # +UIDPLUS+ ABNF:: https://www.rfc-editor.org/rfc/rfc4315.html#section-4
      #   resp-code-apnd  = "APPENDUID" SP nz-number SP append-uid
      #   append-uid      = uniqueid
      #   append-uid      =/ uid-set
      #                     ; only permitted if client uses [MULTIAPPEND]
      #                     ; to append multiple messages.
      #
      # n.b, uniqueid ⊂ uid-set.  To avoid inconsistent return types, we always
      # match uid_set even if that returns a single-member array.
      #
      def resp_code_apnd__data
        match(T_SPACE); validity = number
        match(T_SPACE); dst_uids = uid_set # uniqueid ⊂ uid-set
        UIDPlusData.new(validity, nil, dst_uids)
      end

      # already matched:  "COPYUID"
      #
      # resp-code-copy  = "COPYUID" SP nz-number SP uid-set SP uid-set
      def resp_code_copy__data
        match(T_SPACE); validity = number
        match(T_SPACE); src_uids = uid_set
        match(T_SPACE); dst_uids = uid_set
        UIDPlusData.new(validity, src_uids, dst_uids)
      end

      def address_list
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        else
          result = []
          match(T_LPAR)
          while true
            token = lookahead
            case token.symbol
            when T_RPAR
              shift_token
              break
            when T_SPACE
              shift_token
            end
            result.push(address)
          end
          return result
        end
      end

      ADDRESS_REGEXP = /\G\
(?# 1: NAME     )(?:NIL|"((?:[^\x80-\xff\x00\r\n"\\]|\\["\\])*)") \
(?# 2: ROUTE    )(?:NIL|"((?:[^\x80-\xff\x00\r\n"\\]|\\["\\])*)") \
(?# 3: MAILBOX  )(?:NIL|"((?:[^\x80-\xff\x00\r\n"\\]|\\["\\])*)") \
(?# 4: HOST     )(?:NIL|"((?:[^\x80-\xff\x00\r\n"\\]|\\["\\])*)")\
\)/ni

      def address
        match(T_LPAR)
        if @str.index(ADDRESS_REGEXP, @pos)
          # address does not include literal.
          @pos = $~.end(0)
          name = $1
          route = $2
          mailbox = $3
          host = $4
          for s in [name, route, mailbox, host]
            Patterns.unescape_quoted! s
          end
        else
          name = nstring
          match(T_SPACE)
          route = nstring
          match(T_SPACE)
          mailbox = nstring
          match(T_SPACE)
          host = nstring
          match(T_RPAR)
        end
        return Address.new(name, route, mailbox, host)
      end

      FLAG_REGEXP = /\
(?# FLAG        )\\([^\x80-\xff(){ \x00-\x1f\x7f%"\\]+)|\
(?# ATOM        )([^\x80-\xff(){ \x00-\x1f\x7f%*"\\]+)/n

      def flag_list
        if @str.index(/\(([^)]*)\)/ni, @pos)
          @pos = $~.end(0)
          return $1.scan(FLAG_REGEXP).collect { |flag, atom|
            if atom
              atom
            else
              flag.capitalize.intern
            end
          }
        else
          parse_error("invalid flag list")
        end
      end

      def nstring
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        else
          return string
        end
      end

      def astring
        token = lookahead
        if string_token?(token)
          return string
        else
          return astring_chars
        end
      end

      def string
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        end
        token = match(T_QUOTED, T_LITERAL)
        return token.value
      end

      STRING_TOKENS = [T_QUOTED, T_LITERAL, T_NIL]

      def string_token?(token)
        return STRING_TOKENS.include?(token.symbol)
      end

      def case_insensitive_string
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        end
        token = match(T_QUOTED, T_LITERAL)
        return token.value.upcase
      end

      # atom            = 1*ATOM-CHAR
      # ATOM-CHAR       = <any CHAR except atom-specials>
      ATOM_TOKENS = [
        T_ATOM,
        T_NUMBER,
        T_NIL,
        T_LBRA,
        T_PLUS
      ]

      # ASTRING-CHAR    = ATOM-CHAR / resp-specials
      # resp-specials   = "]"
      ASTRING_CHARS_TOKENS = [*ATOM_TOKENS, T_RBRA]

      def astring_chars
        combine_adjacent(*ASTRING_CHARS_TOKENS)
      end

      def combine_adjacent(*tokens)
        result = "".b
        while token = accept(*tokens)
          result << token.value
        end
        if result.empty?
          parse_error('unexpected token %s (expected %s)',
                      lookahead.symbol, args.join(" or "))
        end
        result
      end

      # See https://www.rfc-editor.org/errata/rfc3501
      #
      # charset = atom / quoted
      def charset
        if token = accept(T_QUOTED)
          token.value
        else
          atom
        end
      end

      def number
        token = lookahead
        if token.symbol == T_NIL
          shift_token
          return nil
        end
        token = match(T_NUMBER)
        return token.value.to_i
      end

      # RFC-4315 (UIDPLUS) or RFC9051 (IMAP4rev2):
      #      uid-set         = (uniqueid / uid-range) *("," uid-set)
      #      uid-range       = (uniqueid ":" uniqueid)
      #                          ; two uniqueid values and all values
      #                          ; between these two regardless of order.
      #                          ; Example: 2:4 and 4:2 are equivalent.
      #      uniqueid        = nz-number
      #                          ; Strictly ascending
      def uid_set
        token = match(T_NUMBER, T_ATOM)
        case token.symbol
        when T_NUMBER then [Integer(token.value)]
        when T_ATOM
          token.value.split(",").flat_map {|range|
            range = range.split(":").map {|uniqueid| Integer(uniqueid) }
            range.size == 1 ? range : Range.new(range.min, range.max).to_a
          }
        end
      end

      def nil_atom
        match(T_NIL)
        return nil
      end

      SPACES_REGEXP = /\G */n

      # The RFC is very strict about this and usually we should be too.
      # But skipping spaces is usually a safe workaround for buggy servers.
      #
      # This advances @pos directly so it's safe before changing @lex_state.
      def accept_spaces
        shift_token if @token&.symbol == T_SPACE
        if @str.index(SPACES_REGEXP, @pos)
          @pos = $~.end(0)
        end
      end

      def next_token
        case @lex_state
        when EXPR_BEG
          if @str.index(BEG_REGEXP, @pos)
            @pos = $~.end(0)
            if $1
              return Token.new(T_SPACE, $+)
            elsif $2
              return Token.new(T_NIL, $+)
            elsif $3
              return Token.new(T_NUMBER, $+)
            elsif $4
              return Token.new(T_ATOM, $+)
            elsif $5
              return Token.new(T_QUOTED, Patterns.unescape_quoted($+))
            elsif $6
              return Token.new(T_LPAR, $+)
            elsif $7
              return Token.new(T_RPAR, $+)
            elsif $8
              return Token.new(T_BSLASH, $+)
            elsif $9
              return Token.new(T_STAR, $+)
            elsif $10
              return Token.new(T_LBRA, $+)
            elsif $11
              return Token.new(T_RBRA, $+)
            elsif $12
              len = $+.to_i
              val = @str[@pos, len]
              @pos += len
              return Token.new(T_LITERAL, val)
            elsif $13
              return Token.new(T_PLUS, $+)
            elsif $14
              return Token.new(T_PERCENT, $+)
            elsif $15
              return Token.new(T_CRLF, $+)
            elsif $16
              return Token.new(T_EOF, $+)
            else
              parse_error("[Net::IMAP BUG] BEG_REGEXP is invalid")
            end
          else
            @str.index(/\S*/n, @pos)
            parse_error("unknown token - %s", $&.dump)
          end
        when EXPR_DATA
          if @str.index(DATA_REGEXP, @pos)
            @pos = $~.end(0)
            if $1
              return Token.new(T_SPACE, $+)
            elsif $2
              return Token.new(T_NIL, $+)
            elsif $3
              return Token.new(T_NUMBER, $+)
            elsif $4
              return Token.new(T_QUOTED, Patterns.unescape_quoted($+))
            elsif $5
              len = $+.to_i
              val = @str[@pos, len]
              @pos += len
              return Token.new(T_LITERAL, val)
            elsif $6
              return Token.new(T_LPAR, $+)
            elsif $7
              return Token.new(T_RPAR, $+)
            else
              parse_error("[Net::IMAP BUG] DATA_REGEXP is invalid")
            end
          else
            @str.index(/\S*/n, @pos)
            parse_error("unknown token - %s", $&.dump)
          end
        else
          parse_error("invalid @lex_state - %s", @lex_state.inspect)
        end
      end

    end
  end
end
