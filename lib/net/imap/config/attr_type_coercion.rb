# frozen_string_literal: true

module Net
  class IMAP
    class Config
      # >>>
      #   *NOTE:* This module is an internal implementation detail, with no
      #   guarantee of backward compatibility.
      #
      # Adds a +type+ keyword parameter to +attr_accessor+, to enforce that
      # config attributes have valid types, for example: boolean, numeric,
      # enumeration, non-nullable, etc.
      module AttrTypeCoercion
        # :stopdoc: internal APIs only

        module Macros # :nodoc: internal API
          def attr_accessor(attr, type: nil)
            super(attr)
            AttrTypeCoercion.attr_accessor(attr, type: type)
          end
        end
        private_constant :Macros

        def self.included(mod)
          mod.extend Macros
        end
        private_class_method :included

        Types = Hash.new do |h, type| type => Proc | nil; type end
        Types[:boolean] = Boolean = -> {!!_1}
        Types[Integer]  = ->{Integer(_1)}

        def self.attr_accessor(attr, type: nil)
          type = Types[type] or return
          define_method :"#{attr}=" do |val| super type[val] end
          define_method :"#{attr}?" do send attr end if type == Boolean
        end

        Enum = ->(*enum) {
          enum = enum.dup.freeze
          expected = -"one of #{enum.map(&:inspect).join(", ")}"
          ->val {
            return val if enum.include?(val)
            raise ArgumentError, "expected %s, got %p" % [expected, val]
          }
        }

      end
    end
  end
end
