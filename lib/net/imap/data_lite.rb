# frozen_string_literal: true

module Net
  class IMAP
    # DataLite subclasses ruby's +Data+ class and is aliased as Net::IMAP::Data,
    # so that code using it won't need to be updated when it is removed.  It
    # adds support for yaml encoding.  When psych adds support for Data,
    # DataLite _will_ be removed.
    #
    # Previously, DataLite served as a reimplementation of +Data+ for ruby 3.1.
    class DataLite < ::Data
      def encode_with(coder) coder.map = to_h.transform_keys(&:to_s)        end
      def init_with(coder) initialize(**coder.map.transform_keys(&:to_sym)) end
    end

    Data = DataLite
  end
end
