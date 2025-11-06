# frozen_string_literal: true

require "forwardable"

module Net
  class IMAP
    class Config
      # >>>
      #   *NOTE:* This module is an internal implementation detail, with no
      #   guarantee of backward compatibility.
      #
      # Adds a +defaults+ parameter to +attr_accessor+, which is used to compile
      # Config.version_defaults.
      module AttrVersionDefaults
        # See Config.version_defaults.
        singleton_class.attr_accessor :version_defaults

        @version_defaults = Hash.new {|h, k|
          # NOTE: String responds to both so the order is significant.
          # And ignore non-numeric conversion to zero, because: "wat!?".to_r == 0
          (h.fetch(k.to_r, nil) || h.fetch(k.to_f, nil) if k.is_a?(Numeric)) ||
            (h.fetch(k.to_sym, nil) if k.respond_to?(:to_sym)) ||
            (h.fetch(k.to_r,   nil) if k.respond_to?(:to_r) && k.to_r != 0r) ||
            (h.fetch(k.to_f,   nil) if k.respond_to?(:to_f) && k.to_f != 0.0)
        }

        # :stopdoc: internal APIs only

        def self.compile_version_defaults!
          version_defaults.freeze
        end

      end
    end
  end
end
