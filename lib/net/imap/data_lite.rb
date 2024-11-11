# frozen_string_literal: true

# Some of the code in this file was copied from the polyfill-data gem.
#
# MIT License
#
# Copyright (c) 2023 Jim Gay, Joel Drapper, Nicholas Evans
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# TODO: fix tests to allow same yaml for both Data and DataLite
# NOTE: psych 5.1.2 doesn't encode ::Data correctly!
# if RUBY_VERSION >= "3.2.0"
#   return
# end

module Net
  class IMAP

    # See {ruby's documentation for Data}[https://docs.ruby-lang.org/en/3.3/Data.html].
    #
    # DataLite is a temporary polyfill for ruby 3.2's
    # Data[https://docs.ruby-lang.org/en/3.3/Data.html].  <em>This class is
    # not defined for ruby versions >= 3.2.</em>  It will only be defined when
    # using ruby 3.1 (+net-imap+ no longer supports ruby versions < 3.1).  It
    # <em>will be removed</em> in +net-imap+ 0.6, when support for ruby 3.1 is
    # dropped.
    #
    # It is aliased as Net::IMAP::Data so that, in ruby 3.1, any reference to
    # "Data" that is namespaced inside Net::IMAP will use it.  This way,
    # Net::IMAP's code shouldn't need to change to work with both
    # Net::IMAP::DataLite and
    # {::Data}[https://docs.ruby-lang.org/en/3.3/Data.html].
    #
    # Some of the code in this class was copied or adapted from the
    # {polyfill-data gem}[https://rubygems.org/gems/polyfill-data], by Jim Gay
    # and Joel Drapper, under the MIT license terms.
    class DataLite
      singleton_class.undef_method :new

      TYPE_ERROR    = "%p is not a symbol nor a string"
      ATTRSET_ERROR = "invalid data member: %p"
      DUP_ERROR     = "duplicate member: %p"
      ARITY_ERROR   = "wrong number of arguments (given %d, expected %s)"
      private_constant :TYPE_ERROR, :ATTRSET_ERROR, :DUP_ERROR, :ARITY_ERROR

      # *NOTE:+ DataLite.define does not support member names which are not
      # valid local variable names.
      def self.define(*args, &block)
        members = args.each_with_object({}) do |arg, members|
          arg = arg.to_str unless arg in Symbol | String if arg.respond_to?(:to_str)
          arg = arg.to_sym if     arg in String
          arg in Symbol     or  raise TypeError,     TYPE_ERROR    % [arg]
          arg in %r{=}      and raise ArgumentError, ATTRSET_ERROR % [arg]
          members.key?(arg) and raise ArgumentError, DUP_ERROR     % [arg]
          members[arg] = true
        end
        members = members.keys.freeze

        klass = ::Class.new(self)

        klass.singleton_class.undef_method :define
        klass.define_singleton_method(:members) { members }

        def klass.new(*args, **kwargs, &block)
          if kwargs.size.positive?
            if args.size.positive?
              raise ArgumentError, ARITY_ERROR % [args.size, 0]
            end
          elsif members.size < args.size
            expected = members.size.zero? ? 0 : 0..members.size
            raise ArgumentError, ARITY_ERROR % [args.size, expected]
          else
            kwargs = Hash[members.take(args.size).zip(args)]
          end
          allocate.tap do |instance|
            instance.__send__(:initialize, **kwargs, &block)
          end.freeze
        end

        klass.singleton_class.alias_method :[], :new
        klass.attr_reader(*members)

        # Dynamically defined initializer methods are in an included module,
        # rather than directly on DataLite (like in ruby 3.2+):
        # * simpler to handle required kwarg ArgumentErrors
        # * easier to ensure consistent ivar assignment order (object shape)
        # * faster than instance_variable_set
        klass.include(Module.new do
          if members.any?
            kwargs = members.map{"#{_1.name}:"}.join(", ")
            params = members.map(&:name).join(", ")
            ivars  = members.map{"@#{_1.name}"}.join(", ")
            attrs  = members.map{"attrs[:#{_1.name}]"}.join(", ")
            module_eval <<~RUBY, __FILE__, __LINE__ + 1
              protected
              def initialize(#{kwargs}) #{ivars} = #{params}; freeze end
              def marshal_load(attrs)   #{ivars} = #{attrs};  freeze end
            RUBY
          end
        end)

        klass.module_eval do _1.module_eval(&block) end if block_given?

        klass
      end

      def members;     self.class.members                              end
      def attributes;  Hash[members.map {|m| [m, send(m)] }]           end
      def to_h(&block) attributes.to_h(&block)                         end
      def hash;        to_h.hash                                       end
      def ==(other)    self.class == other.class && to_h == other.to_h end
      def eql?(other)  self.class == other.class && hash == other.hash end
      def deconstruct; attributes.values                               end

      def deconstruct_keys(keys)
        raise TypeError unless keys.is_a?(Array) || keys.nil?
        return attributes if keys&.first.nil?
        attributes.slice(*keys)
      end

      def with(**kwargs)
        return self if kwargs.empty?
        self.class.new(**attributes.merge(kwargs))
      end

      # +NOTE:+ Unlike ruby 3.2's <tt>Data#inspect</tt>, this has no guard
      # against infinite recursion.
      def inspect
        attrs   = attributes.map {|kv| "%s=%p" % kv }.join(", ")
        display = ["data", self.class.name, attrs].compact.join(" ")
        "#<#{display}>"
      end
      alias_method :to_s, :inspect

      def encode_with(coder) coder.map = attributes.transform_keys(&:to_s) end
      def init_with(coder) marshal_load(coder.map.transform_keys(&:to_sym)) end

      private

      def initialize_copy(source) super.freeze end
      def marshal_dump; attributes end

    end

    Data = DataLite

  end
end
