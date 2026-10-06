# frozen_string_literal: true
# shareable_constant_value: literal

# :enddoc:

module Net
  class IMAP < Protocol

    # INTERNAL utility methods.  API is unstable and subject to change.
    module Utils
      module_function

      if defined?(Ractor.shareable_proc)
        def shareable
          case obj = yield
          when Proc
            Ractor.shareable_proc(&obj)
          else
            Ractor.make_shareable obj
          end
        end
      elsif defined?(Ractor.make_shareable)
        def shareable(&b)
          obj = nil.instance_eval(&b).freeze
          Ractor.make_shareable obj
        end
      else
        def shareable(&b) nil.instance_eval(&b).freeze end
      end

    end
  end
end
