# frozen_string_literal: false

require "net/imap"
require "test/unit"

# This test file was copied from the polyfill-data gem.
#
# MIT License
#
# Copyright (c) 2023 Jim Gay
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

module Net
  class IMAP
    class TestData < Test::Unit::TestCase
      def test_define
        klass = Data.define(:foo, :bar)
        assert_kind_of(Class, klass)
        assert_equal(%i[foo bar], klass.members)

        assert_raise(NoMethodError) { Data.new(:foo) }
        assert_raise(TypeError) { Data.define(0) }

        # Because some code is shared with Struct, check we don't share unnecessary functionality
        assert_raise(TypeError) { Data.define(:foo, keyword_init: true) }

        refute_respond_to(Data.define, :define, "Cannot define from defined Data class")
      end

      def test_define_edge_cases
        # non-ascii
        klass = Data.define(:"r\u{e9}sum\u{e9}")
        o = klass.new(1)
        assert_equal(1, o.send(:"r\u{e9}sum\u{e9}"))

        assert_raise(ArgumentError) { Data.define(:x=) }
        assert_raise(ArgumentError, /duplicate member/) { Data.define(:x, :x) }
      end

      def test_define_with_block
        klass = Data.define(:a, :b) do
          def c
            a + b
          end
        end

        assert_equal(3, klass.new(1, 2).c)
      end

      def test_initialize
        klass = Data.define(:foo, :bar)

        # Regular
        test = klass.new(1, 2)
        assert_equal(1, test.foo)
        assert_equal(2, test.bar)
        assert_equal(test, klass.new(1, 2))
        assert_predicate(test, :frozen?)

        # Keywords
        test_kw = klass.new(foo: 1, bar: 2)
        assert_equal(1, test_kw.foo)
        assert_equal(2, test_kw.bar)
        assert_equal(test_kw, klass.new(foo: 1, bar: 2))
        assert_equal(test_kw, test)

        # Wrong protocol
        assert_raise(ArgumentError) { klass.new(1) }
        assert_raise(ArgumentError) { klass.new(1, 2, 3) }
        assert_raise(ArgumentError) { klass.new(foo: 1) }
        assert_raise(ArgumentError) { klass.new(foo: 1, bar: 2, baz: 3) }
        # Could be converted to foo: 1, bar: 2, but too smart is confusing
        assert_raise(ArgumentError) { klass.new(1, bar: 2) }
      end

      def test_initialize_redefine
        klass = Data.define(:foo, :bar) do
          attr_reader :passed

          def initialize(*args, **kwargs)
            @passed = [args, kwargs]

            super(foo: 1, bar: 2) # so we can experiment with passing wrong numbers of args
          end
        end

        assert_equal([[], {foo: 1, bar: 2}], klass.new(foo: 1, bar: 2).passed)

        # Positional arguments are converted to keyword ones
        assert_equal([[], {foo: 1, bar: 2}], klass.new(1, 2).passed)

        # Missing arguments can be fixed in initialize
        assert_equal([[], {foo: 1}], klass.new(foo: 1).passed)

        # Extra keyword arguments can be dropped in initialize
        assert_equal([[], {foo: 1, bar: 2, baz: 3}], klass.new(foo: 1, bar: 2, baz: 3).passed)
      end

      def test_instance_behavior
        klass = Data.define(:foo, :bar)

        test = klass.new(1, 2)
        assert_equal(1, test.foo)
        assert_equal(2, test.bar)
        assert_equal(%i[foo bar], test.members)
        assert_equal(1, test.public_send(:foo))
        assert_equal(0, test.method(:foo).arity)
        assert_equal([], test.method(:foo).parameters)

        assert_equal({foo: 1, bar: 2}, test.to_h)
        assert_equal({"foo"=>"1", "bar"=>"2"}, test.to_h { [_1.to_s, _2.to_s] })

        assert_equal({foo: 1, bar: 2}, test.deconstruct_keys(nil))
        assert_equal({foo: 1}, test.deconstruct_keys(%i[foo]))
        assert_equal({foo: 1}, test.deconstruct_keys(%i[foo baz]))
        assert_raise(TypeError) { test.deconstruct_keys(0) }

        test = klass.new(bar: 2, foo: 1)
        assert_equal([1, 2], test.deconstruct)

        assert_kind_of(Integer, test.hash)
      end

      def test_inspect
        klass = Data.define(:a)
        o = klass.new(1)
        assert_equal("#<data a=1>", o.inspect)

        Object.const_set(:Foo, klass)
        assert_equal("#<data Foo a=1>", o.inspect)
        Object.instance_eval { remove_const(:Foo) }

        klass = Data.define(:one, :two)
        o = klass.new(1,2)
        assert_equal("#<data one=1, two=2>", o.inspect)
        assert_equal("#<data one=1, two=2>", o.to_s)
      end

      def test_recursive_inspect
        # TODO: TruffleRuby's Data fails this test with a StackOverflowError
        klass = Data.define(:value, :head, :tail) do
          def initialize(value:, head: nil, tail: nil)
            case tail
            in Array if tail.empty?
              tail = nil
            in Array
              succ, *rest = *tail
              tail = self.class[head: self, value: succ, tail: rest]
            in [tailprev, _, _] if tail.class == self.class && tailprev == self
              # noop
            in [tailprev, succ, rest] if tail.class == self.class
              tail = self.class[head: self, value: succ, tail: rest]
            in nil
            else
              tail = self.class[head: self, value: tail, tail: nil]
            end
            super(head:, value:, tail:)
          end
        end

        # anonymous class
        list = klass[value: 1, tail: [2, 3, 4]]
        seen = "#<data #{klass.inspect}:...>"
        assert_equal(
          "#<data value=1, head=nil," \
          " tail=#<data value=2, head=#{seen}," \
          " tail=#<data value=3, head=#{seen}," \
          " tail=#<data value=4, head=#{seen}," \
          " tail=nil>>>>",
          # TODO: JRuby's Data fails on the next line
          list.inspect
        )

        # named class
        Object.const_set(:DoubleLinkList, klass)
        list = DoubleLinkList[value: 1, tail: [2, 3, 4]]
        seen = "#<data DoubleLinkList:...>"
        assert_equal(
          "#<data DoubleLinkList value=1, head=nil," \
          " tail=#<data DoubleLinkList value=2, head=#{seen}," \
          " tail=#<data DoubleLinkList value=3, head=#{seen}," \
          " tail=#<data DoubleLinkList value=4, head=#{seen}," \
          " tail=nil>>>>",
          # TODO: JRuby's Data fails on the next line
          list.inspect
        )
      ensure
        Object.instance_eval { remove_const(:DoubleLinkList) } rescue nil
      end

      def test_equal
        klass1 = Data.define(:a)
        klass2 = Data.define(:a)
        o1 = klass1.new(1)
        o2 = klass1.new(1)
        o3 = klass2.new(1)
        assert_equal(o1, o2)
        refute_equal(o1, o3)
      end

      def test_eql
        klass1 = Data.define(:a)
        klass2 = Data.define(:a)
        o1 = klass1.new(1)
        o2 = klass1.new(1)
        o3 = klass2.new(1)
        assert_operator(o1, :eql?, o2)
        refute_operator(o1, :eql?, o3)
      end

      def test_with
        klass = Data.define(:foo, :bar)
        source = klass.new(foo: 1, bar: 2)

        # Simple
        test = source.with
        assert_equal(source.object_id, test.object_id)

        # Changes
        test = source.with(foo: 10)

        assert_equal(1, source.foo)
        assert_equal(2, source.bar)
        assert_equal(source, klass.new(foo: 1, bar: 2))

        assert_equal(10, test.foo)
        assert_equal(2, test.bar)
        assert_equal(test, klass.new(foo: 10, bar: 2))

        test = source.with(foo: 10, bar: 20)

        assert_equal(1, source.foo)
        assert_equal(2, source.bar)
        assert_equal(source, klass.new(foo: 1, bar: 2))

        assert_equal(10, test.foo)
        assert_equal(20, test.bar)
        assert_equal(test, klass.new(foo: 10, bar: 20))

        # Keyword splat
        changes = { foo: 10, bar: 20 }
        test = source.with(**changes)

        assert_equal(1, source.foo)
        assert_equal(2, source.bar)
        assert_equal(source, klass.new(foo: 1, bar: 2))

        assert_equal(10, test.foo)
        assert_equal(20, test.bar)
        assert_equal(test, klass.new(foo: 10, bar: 20))

        # Wrong protocol
        assert_raise(ArgumentError, "wrong number of arguments (given 1, expected 0)") do
          source.with(10)
        end
        assert_raise(ArgumentError, "unknown keywords: :baz, :quux") do
          source.with(foo: 1, bar: 2, baz: 3, quux: 4)
        end
        assert_raise(ArgumentError, "wrong number of arguments (given 1, expected 0)") do
          source.with(1, bar: 2)
        end
        assert_raise(ArgumentError, "wrong number of arguments (given 2, expected 0)") do
          source.with(1, 2)
        end
        assert_raise(ArgumentError, "wrong number of arguments (given 1, expected 0)") do
          source.with({ bar: 2 })
        end unless RUBY_VERSION < "2.8.0"
      end

      def test_memberless
        klass = Data.define

        test = klass.new

        assert_equal(klass.new, test)
        refute_equal(Data.define.new, test)

        assert_equal('#<data >', test.inspect)
        assert_equal([], test.members)
        assert_equal({}, test.to_h)
      end

      def test_square_braces
        klass = Data.define(:amount, :unit)

        distance = klass[10, 'km']

        assert_equal(10, distance.amount)
        assert_equal('km', distance.unit)
      end

      def test_dup
        klass = Data.define(:foo, :bar)
        test = klass.new(foo: 1, bar: 2)
        assert_equal(klass.new(foo: 1, bar: 2), test.dup)
        assert_predicate(test.dup, :frozen?)
      end

      Klass = Data.define(:foo, :bar)

      def test_marshal
        test = Klass.new(foo: 1, bar: 2)
        loaded = Marshal.load(Marshal.dump(test))
        assert_equal(test, loaded)
        refute_same(test, loaded)
        assert_predicate(loaded, :frozen?)
      end

      def test_member_precedence
        name_mod = Module.new do
          def name
            "default name"
          end

          def other
            "other"
          end
        end

        klass = Data.define(:name) do
          include name_mod
        end

        data = klass.new("test")

        assert_equal("test", data.name)
        assert_equal("other", data.other)
      end

      class Abstract < Data
      end

      class Inherited < Abstract.define(:foo)
      end

      def test_subclass_can_create
        # TODO: JRuby's Data fails all of these
        assert_equal 1, Inherited[1]    .foo
        assert_equal 2, Inherited[foo: 2].foo
        assert_equal 3, Inherited.new(3).foo
        assert_equal 4, Inherited.new(foo: 4).foo
      end

      class AbstractWithClassMethod < Data
        def self.inherited_class_method; :ok end
      end

      class InheritsClassMethod < AbstractWithClassMethod.define(:foo)
      end

      def test_subclass_class_method
        # TODO: JRuby's Data fails on the next line
        assert_equal :ok, InheritsClassMethod.inherited_class_method
      end

      class AbstractWithOverride < Data
        def deconstruct; [:ok, *super] end
      end

      class InheritsOverride < AbstractWithOverride.define(:foo)
      end

      def test_subclass_override_deconstruct
        # TODO: JRuby's Data fails on the next line
        data = InheritsOverride[:foo]
        # TODO: TruffleRuby's Data fails on the next line
        assert_equal %i[ok foo], data.deconstruct
      end

    end
  end
end
