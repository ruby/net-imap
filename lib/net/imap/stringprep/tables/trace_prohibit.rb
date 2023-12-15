# frozen_string_literal: true

#--
# This file is generated by `rake stringprep:tables`.  Don't edit directly.
#++

module Net::IMAP::StringPrep
  module Tables

    # Combines C.2.1, C.2.2, C.3, C.4, C.5, C.6, C.8, C.9.
    # Used by the "trace" profile.
    TRACE_PROHIBIT = /[\u{06dd 070f 180e feff e0001}\u{0000}-\u{001f}\u{007f}-\u{009f}\u{0340}-\u{0341}\u{200c}-\u{200f}\u{2028}-\u{202e}\u{2060}-\u{2063}\u{206a}-\u{206f}\u{e000}-\u{f8ff}\u{fdd0}-\u{fdef}\u{fff9}-\u{ffff}\u{1d173}-\u{1d17a}\u{1fffe}-\u{1ffff}\u{2fffe}-\u{2ffff}\u{3fffe}-\u{3ffff}\u{4fffe}-\u{4ffff}\u{5fffe}-\u{5ffff}\u{6fffe}-\u{6ffff}\u{7fffe}-\u{7ffff}\u{8fffe}-\u{8ffff}\u{9fffe}-\u{9ffff}\u{afffe}-\u{affff}\u{bfffe}-\u{bffff}\u{cfffe}-\u{cffff}\u{dfffe}-\u{dffff}\u{e0020}-\u{e007f}\u{efffe}-\u{10ffff}\p{Cs}]/.freeze

  end
end
