# frozen_string_literal: true

require "forwardable"

module Net
  class IMAP
    class Config

      # Config values are stored in a struct rather than ivars to simplify:
      # * ensuring that all config objects share a single object shape
      # * querying only locally configured values, e.g for inspection.
      module AttrAccessors
        module Macros # :nodoc: internal API
          def attr_accessor(name) AttrAccessors.attr_accessor(name) end
        end
        private_constant :Macros

        def self.included(mod)
          mod.extend Macros
        end
        private_class_method :included

        extend Forwardable

        def self.attr_accessor(name) # :nodoc: internal API
          name = name.to_sym
          def_delegators :data, name, :"#{name}="
        end

        def self.attributes
          instance_methods.grep(/=\z/).map { _1.to_s.delete_suffix("=").to_sym }
        end
        private_class_method :attributes

        def self.struct # :nodoc: internal API
          unless defined?(self::Struct)
            const_set :Struct, Struct.new(*attributes)
          end
          self::Struct
        end

        def initialize # :notnew:
          super()
          @data = AttrAccessors.struct.new
        end

        # Freezes the internal attributes struct, in addition to +self+.
        def freeze
          data.freeze
          super
        end

        protected

        attr_reader :data # :nodoc: internal API

        private

        def initialize_dup(other)
          super
          @data = other.data.dup
        end

      end
    end
  end
end
