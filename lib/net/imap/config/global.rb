require "singleton"

module Net
  class IMAP
    class Config
      class Global < Config
        include Singleton
        extend Forwardable
        singleton_class.extend(Forwardable)

        singleton_class.attr_reader :snapshot

        def_delegators :"self.class", :reset, :snapshot
        protected :snapshot

        def self.setup!
          @snapshot = Config.default.new.freeze
          AttrAccessors.attributes.each do |attr|
            singleton_class.define_method(:"#{attr}=") do |val|
              @snapshot = snapshot.dup.update(attr => val).freeze
            end
            singleton_class.def_delegator :snapshot, attr
            def_delegators :"self.class", attr, :"#{attr}="
          end
          instance
        end

        def initialize
          super(Config.default)
          @data = nil
          freeze
        end

        def new(**attrs) Config.new(self, **attrs) end

        def self.reset(attr = nil)
          if attr.nil?
            @snapshot = Config.default.new.freeze
            self
          elsif snapshot.inherited?(attr)
            nil
          else
            old, new = send(attr), snapshot.dup
            new.reset(attr)
            @snapshot = new.freeze
            old
          end
        end

        protected

        def data = snapshot.data

      end
    end
  end
end
