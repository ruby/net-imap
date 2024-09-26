# frozen_string_literal: true

module Net
  class IMAP

    # A temporary polyfill for ruby 3.2's Data class.
    class DataLite

      def self.new(*args, **kwargs, &block)
        if args.any?
          if args.size > members.size
            raise ArgumentError, "unknown arguments #{new_args[members.size..].join(', ')}"
          end
          kwargs = Hash[members.take(args.size).zip(args)]
        end
        allocate.tap do |instance|
          instance.send(:initialize, **kwargs, &block)
        end.freeze
      end
      singleton_class.alias_method :[], :new

      def members;     self.class.members                    end
      def attributes;  Hash[members.map {|m| [m, send(m)] }] end
      def to_h(&block) attributes.to_h(&block)               end
      def hash;        to_h.hash                             end
      def deconstruct; attributes.values                     end

      def deconstruct_keys(keys)
        raise TypeError unless keys.is_a?(Array) || keys.nil?
        return attributes if keys&.first.nil?
        attributes.slice(*keys)
      end

      def ==(other)
        self.class == other.class && to_h == other.to_h
      end

      def eql?(other)
        self.class == other.class && hash == other.hash
      end

      def with(**kwargs)
        return self if kwargs.empty?
        self.class.new(**attributes.merge(kwargs))
      end

      private

      def initialize_copy(source)
        super.freeze
      end

    end

  end
end
