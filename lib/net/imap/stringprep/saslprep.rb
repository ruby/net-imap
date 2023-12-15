# frozen_string_literal: true

module Net
  class IMAP
    module StringPrep

      # SASLprep#saslprep can be used to prepare a string according to
      # RFC4013[https://tools.ietf.org/html/rfc4013].
      #
      # \SASLprep maps characters three ways: to nothing, to space, and Unicode
      # normalization form KC.  \SASLprep prohibits codepoints from nearly all
      # standard StringPrep tables
      # (RFC3454[https://tools.ietf.org/html/rfc3454], Appendix "C"), and uses
      # \StringPrep's standard bidirectional characters requirements (Appendix
      # "D").  \SASLprep also uses \StringPrep's definition of "Unassigned"
      # codepoints (Appendix "A").
      module SASLprep
        # Avoid loading these tables unless they are needed (for non-ASCII).
        autoload :PROHIBITED_OUTPUT,        "#{__dir__}/saslprep/prohibited.rb"
        autoload :PROHIBITED_OUTPUT_STORED, "#{__dir__}/saslprep/prohibited.rb"
        autoload :PROHIBITED,               "#{__dir__}/saslprep/prohibited.rb"
        autoload :PROHIBITED_STORED,        "#{__dir__}/saslprep/prohibited.rb"

        # Defined in RFC4013[https://tools.ietf.org/html/rfc4013].
        STRINGPREP_PROFILE = "SASLprep"

        # Used to short-circuit strings that don't need preparation.
        ASCII_NO_CTRLS = /\A[\x20-\x7e]*\z/u.freeze

        # Regexp for RFC4013[https://tools.ietf.org/html/rfc4013] §2.1 Mapping -
        # mapped to space
        MAP_TO_SPACE = Tables::IN_C_1_2

        # Regexp for RFC4013[https://tools.ietf.org/html/rfc4013] §2.1 Mapping -
        # mapped to nothing
        MAP_TO_NOTHING = Tables::IN_B_1

        # RFC4013[https://tools.ietf.org/html/rfc4013] §2.1 Mapping
        # >>>
        #   This profile specifies:
        #   - non-ASCII space characters (\StringPrep\[\"C.1.2\"]) that can
        #     be mapped to SPACE (U+0020)
        #   - the "commonly mapped to nothing" characters
        #     (\StringPrep\[\"B.1\"]) that can be mapped to nothing.
        MAPPINGS = {
          MAP_TO_SPACE   => " ",
          MAP_TO_NOTHING => "",
        }.freeze

        # RFC4013[https://tools.ietf.org/html/rfc4013] §2.2 Normalization
        # >>>
        #   This profile specifies using Unicode normalization form KC, as
        #   described in Section 4 of [StringPrep].
        NORMALIZATION = :nfkc

        # RFC4013[https://tools.ietf.org/html/rfc4013] §2.3 Prohibited Output
        # >>>
        # * Non-ASCII space characters — \StringPrep\[\"C.1.2\"]
        # * ASCII control characters — \StringPrep\[\"C.2.1\"]
        # * Non-ASCII control characters — \StringPrep\[\"C.2.2\"]
        # * Private Use characters — \StringPrep\[\"C.3\"]
        # * Non-character code points — \StringPrep\[\"C.4\"]
        # * Surrogate code points — \StringPrep\[\"C.5\"]
        # * Inappropriate for plain text characters — \StringPrep\[\"C.6\"]
        # * Inappropriate for canonical representation characters — \StringPrep\[\"C.7\"]
        # * Change display properties or deprecated characters — \StringPrep\[\"C.8\"]
        # * Tagging characters — \StringPrep\[\"C.9\"]
        PROHIBITED_TABLES = %w[C.1.2 C.2.1 C.2.2 C.3 C.4 C.5 C.6 C.7 C.8 C.9]
          .freeze

        # RFC4013[https://tools.ietf.org/html/rfc4013] §2.4 Bidirectional
        # Characters
        # >>>
        #   This profile specifies checking bidirectional strings as described
        #   in [StringPrep, Section 6].
        CHECK_BIDI = true

        # RFC4013[https://tools.ietf.org/html/rfc4013] §2.5 Unassigned Code
        # Points
        # >>>
        #   This profile specifies the \StringPrep\[\"A.1\"] table as its
        #   list of unassigned code points.
        UNASSIGNED_TABLE = "A.1"

        # :nodoc:
        UNASSIGNED = Tables::IN_A_1
        deprecate_constant :UNASSIGNED

        module_function

        # Prepares a UTF-8 +string+ for comparison, using the \SASLprep profile
        # {[RFC4013]}[https://tools.ietf.org/html/rfc4013] of the StringPrep
        # algorithm {[RFC3454]}[https://tools.ietf.org/html/rfc3454].
        #
        # By default, prohibited strings will return +nil+.  When +exception+ is
        # +true+, a StringPrepError describing the violation will be raised.
        #
        # When +stored+ is +true+, "unassigned" codepoints will be prohibited.
        # For \StringPrep and the \SASLprep profile, "unassigned" refers to
        # Unicode 3.2, and not later versions.  See RFC3454[https://tools.ietf.org/html/rfc3454] §7 for more
        # information.
        def saslprep(original, stored: false, exception: false)
          return original if ASCII_NO_CTRLS.match?(original) # incompatible encoding raises
          if exception
            StringPrep.stringprep(
              original,
              unassigned:    UNASSIGNED_TABLE,
              maps:          MAPPINGS,
              prohibited:    PROHIBITED_TABLES,
              normalization: NORMALIZATION,
              bidi:          CHECK_BIDI,
              stored:        stored,
              profile:       STRINGPREP_PROFILE,
            )
          else
            str = original.encode("UTF-8") # also dups (and raises for invalid encoding)
            str.gsub!(MAP_TO_SPACE, " ")
            str.gsub!(MAP_TO_NOTHING, "")
            str.unicode_normalize!(:nfkc)
            str unless str.match?(stored ? PROHIBITED_STORED : PROHIBITED)
          end
        rescue ArgumentError, Encoding::CompatibilityError => ex
          if /invalid byte sequence|incompatible encoding/.match? ex.message
            return nil unless exception
            raise StringPrepError.new(ex.message, string: str,
                                      profile: STRINGPREP_PROFILE)
          end
          raise ex
        end

      end

    end
  end
end
