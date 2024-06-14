# frozen_string_literal: true

module Net
  class IMAP
    class Config
      # Adds a +type+ keyword parameter to +attr_accessor+, which enforces
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

        def self.attr_accessor(attr, type: nil)
          return unless type
          if    :boolean == type then boolean attr
          elsif Integer  == type then integer attr
          else raise ArgumentError, "unknown type coercion %p" % [type]
          end
        end

        def self.boolean(attr)
          define_method :"#{attr}=" do |val| super !!val end
          define_method :"#{attr}?" do send attr end
        end

        def self.integer(attr)
          define_method :"#{attr}=" do |val| super Integer val end
        end

      end
    end
  end
end
