# frozen_string_literal: true

module Net::IMAP::StringPrep

  module SASLprep

    # :nodoc:
    PROHIBITED_OUTPUT = Tables::SASLPREP_PROHIBIT

    # :nodoc:
    PROHIBITED_OUTPUT_STORED = Tables::SASLPREP_PROHIBIT_STORED

    # :nodoc:
    PROHIBITED = Regexp.union(PROHIBITED_OUTPUT, Tables::BIDI_FAILURE)

    # :nodoc:
    PROHIBITED_STORED = Regexp.union(
      PROHIBITED_OUTPUT_STORED, Tables::BIDI_FAILURE,
    )

  end
end
