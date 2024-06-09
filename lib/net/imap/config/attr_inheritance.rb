# frozen_string_literal: true

module Net
  class IMAP
    class Config
      # Inheritance forms a singly-linked-list, so lookup will be O(n) on the
      # number of ancestors.  Without customization, ancestor trees will only be
      # three or four deep:
      #     client -> [versioned ->] global -> default
      module AttrInheritance
        INHERITED = Module.new.freeze
        private_constant :INHERITED

        module Macros # :nodoc: internal API
          def attr_accessor(name) super; AttrInheritance.attr_accessor(name) end
        end
        private_constant :Macros

        def self.included(mod)
          mod.extend Macros
        end
        private_class_method :included

        def self.attr_accessor(name) # :nodoc: internal API
          module_eval <<~RUBY, __FILE__, __LINE__ + 1
            def #{name}; (val = super) == INHERITED ? parent&.#{name} : val end
          RUBY
        end

        # The parent Config object
        attr_reader :parent

        def initialize(parent = nil) # :notnew:
          super()
          @parent = Config[parent]
          reset
        end

        # Creates a new config, which inherits from +self+.
        def new(**attrs) self.class.new(self, **attrs) end

        # Returns +true+ if +attr+ is inherited from #parent and not overridden
        # by this config.
        def inherited?(attr) data[attr] == INHERITED end

        # :call-seq:
        #   reset -> self
        #   reset(attr) -> attribute value
        #
        # Resets an +attr+ to inherit from the #parent config.
        #
        # When +attr+ is nil or not given, all attributes are reset.
        def reset(attr = nil)
          if attr.nil?
            data.members.each do |attr| data[attr] = INHERITED end
            self
          elsif inherited?(attr)
            nil
          else
            old, data[attr] = data[attr], INHERITED
            old
          end
        end

        private

        def initialize_copy(other)
          super
          @parent ||= other # only default has nil parent
        end

      end
    end
  end
end
