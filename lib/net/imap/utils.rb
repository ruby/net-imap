# frozen_string_literal: true
# shareable_constant_value: literal

# :enddoc:

module Net
  class IMAP < Protocol

    # INTERNAL utility methods.  API is unstable and subject to change.
    module Utils
      module_function

      # Something like this exists in ruby's C API.  Why not in ruby's ruby?
      def implicit_int(input)
        Integer.try_convert(input) or
          raise TypeError, case input
            when nil
              "no implicit conversion from %p to Integer" % [input]
            when true, false
              "no implicit conversion of %p into Integer" % [input]
            else
              "no implicit conversion of %s into Integer" % [input.class.name]
            end
      end

      if defined?(Ractor.shareable_proc)
        def shareable
          case obj = yield
          when Proc
            Ractor.shareable_proc(&obj)
          else
            Ractor.make_shareable obj
          end
        end

      # simplecov:disable
      elsif defined?(Ractor.make_shareable)
        def shareable(&b)
          obj = nil.instance_eval(&b).freeze
          Ractor.make_shareable obj
        end
      else
        def shareable(&b) nil.instance_eval(&b).freeze end
      end
      # simplecov:enable

    end
  end
end
