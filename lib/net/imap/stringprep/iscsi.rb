# frozen_string_literal: true

module Net
  class IMAP
    module StringPrep

      # Defined in RFC3722[https://tools.ietf.org/html/rfc3722], the +iSCSI+
      # profile of "Stringprep" is used to:
      # >>>
      #   prepare internationalized iSCSI names to increase the likelihood that
      #   name input and comparison work in ways that make sense for typical
      #   users throughout the world.
      #
      #   ...
      #
      #   The goal, then, is to generate iSCSI names that can be transcribed and
      #   entered by users, and also compared byte-for-byte, with minimal
      #   confusion.  To attain these goals, iSCSI names are generalized using a
      #   normalized character set (converted to lower case or equivalent), with
      #   no white space allowed, and very limited punctuation.
      #
      #   - The intended applicability of the profile: internationalized iSCSI
      #     names.
      #   - The character repertoire that is the input and output to
      #     stringprep: Unicode 3.2, specified in section 3.
      #   - The mappings used: specified in section 4.
      #   - The Unicode normalization used: specified in section 5.
      #   - The characters that are prohibited as output: specified in section 6.
      #
      #   This profile MUST be used with the iSCSI protocol.
      module ISCSI

        STRINGPREP_PROFILE = "iSCSI"

        # From RFC3722[https://www.rfc-editor.org/rfc/rfc3722.html] §2
        UNASSIGNED_TABLE = "A.1"

        # From RFC3722[https://www.rfc-editor.org/rfc/rfc3722.html] §3
        MAPPING_TABLES = %w[B.1 B.2].freeze

        # From RFC3722[https://www.rfc-editor.org/rfc/rfc3722.html] §5
        NORMALIZATION = :nfkc

        # From RFC3722[https://www.rfc-editor.org/rfc/rfc3722.html] §6
        PROHIBITED_TABLES = %w[C.1.1 C.1.2 C.2.1 C.2.2 C.3 C.4 C.5 C.6 C.7 C.8 C.9].freeze

        # From RFC3722[https://www.rfc-editor.org/rfc/rfc3722.html] §6.1:
        # >>>
        #   6.1.  Inappropriate Characters from Common Input Mechanisms
        #
        #   u+3002 is used as if it were u+002e in many domain name input
        #   mechanisms used by applications, particularly in Asia.  The character
        #   u+3002 MUST NOT be used in an iSCSI name.
        #
        #      3002; ideographic full stop
        INAPPROPRIATE_FROM_COMMON_INPUT_MECHANISMS = /\u{3002}/.freeze

        # From RFC3722[https://www.rfc-editor.org/rfc/rfc3722.html] §6.2:
        # >>>
        #   6.2.  Currently-prohibited ASCII characters
        #
        #   Some of the ASCII characters that are currently prohibited in iSCSI
        #   names by [RFC3721] are also used in protocol elements such as URIs.
        #   Some examples are described in [RFC2396] and [RFC2732].  Note that
        #   there are many other RFCs that define additional URI schemes.
        #
        #   The other characters in the range U+0000 to U+007F that are not
        #   currently allowed are prohibited in iSCSI names to reserve them for
        #   future use in protocol elements.  Note that the dash (U+002D), dot
        #   (U+002E), and colon (U+003A) are not prohibited.
        #
        #   The following characters MUST NOT be used in iSCSI names:
        #
        #      0000-002C; [ASCII CONTROL CHARACTERS and SPACE through ,]
        #      002F; [ASCII /]
        #      003B-0040; [ASCII ; through @]
        #      005B-0060; [ASCII [ through `]
        #      007B-007F; [ASCII { through DEL]
        PROHIBITED_ASCII = /[\x00-\x2c\x2f\x3b-\x40\x5b-\x60\x7B-\x7f]/.freeze

        # From RFC3722[https://www.rfc-editor.org/rfc/rfc3722.html] §6.2:
        #   In addition, this profile adds the following prohibitions.  The full
        #   set of prohibited characters are those from the tables above plus
        #   those listed individually below.
        PROHIBITED_REGEXP = [
          PROHIBITED_ASCII,
          INAPPROPRIATE_FROM_COMMON_INPUT_MECHANISMS,
        ]
          .map(&:source).join
          .then { /[#{_1}]/ }
          .freeze

        # From RFC3722[https://www.rfc-editor.org/rfc/rfc3722.html] §7
        CHECK_BIDI = true

        module_function

        def stringprep_iscsi(string, **opts)
          StringPrep.stringprep(
            string,
            unassigned:    UNASSIGNED_TABLE,
            maps:          MAPPING_TABLES,
            prohibited:    [*PROHIBITED_TABLES, PROHIBITED_REGEXP],
            normalization: NORMALIZATION,
            bidi:          CHECK_BIDI,
            profile:       STRINGPREP_PROFILE,
            **opts,
          )
        end

      end

    end
  end
end
