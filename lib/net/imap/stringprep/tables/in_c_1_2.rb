# frozen_string_literal: true

#--
# This file is generated by `rake stringprep:tables`.  Don't edit directly.
#++

module Net::IMAP::StringPrep
  module Tables

    # Non-ASCII space characters \StringPrep\[\"C.1.2\"]
    IN_C_1_2 = /[\u200b\p{Zs}&&[^ ]]/.freeze

  end
end
