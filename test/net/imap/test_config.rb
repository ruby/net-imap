# frozen_string_literal: true

require "net/imap"
require "test/unit"

class ConfigTest < Test::Unit::TestCase
  Config = Net::IMAP::Config
  THIS_VERSION   = Net::IMAP::VERSION.to_f
  NEXT_VERSION   = THIS_VERSION + 0.1
  FUTURE_VERSION = THIS_VERSION + 0.2

  setup do
    Config.global.reset
  end

  test "#debug" do
    assert Config.new(debug: true).debug
    refute Config.new(debug: false).debug
    assert Config.new(debug: true).debug?
    refute Config.new(debug: false).debug?
    config = Config.new do |c|
      c.debug = true
    end
    assert config.debug
    config = Config.new
    config.debug = true
    assert config.debug
    assert config.debug?
    config.debug = false
    refute config.debug
    refute config.debug?
  end

  test "boolean type constraints and conversion" do
    config = Config.new
    config.debug = 111
    assert_equal true, config.debug
    config.debug = nil
    assert_equal false, config.debug
  end

  test "integer type constraints and conversion" do
    config = Config.new
    config.open_timeout = "111"
    assert_equal 111, config.open_timeout
    config.open_timeout = 222.0
    assert_equal 222, config.open_timeout
    config.open_timeout = 333.3
    assert_equal 333, config.open_timeout
    assert_raise(ArgumentError) do
      config.open_timeout = "444 NaN"
    end
    assert_equal 333, config.open_timeout
  end

  test "enum type constraint" do
    config = Config.new
    config.responses_without_block = :silence_deprecation_warning
    assert_equal :silence_deprecation_warning, config.responses_without_block
    config.responses_without_block = :warn
    assert_equal :warn, config.responses_without_block
    config.responses_without_block = :raise
    assert_equal :raise, config.responses_without_block
    assert_raise(ArgumentError) do config.responses_without_block = false end
    assert_equal :raise, config.responses_without_block
    assert_raise(ArgumentError) do config.responses_without_block = 12345 end
    assert_equal :raise, config.responses_without_block
    assert_raise(ArgumentError) do config.responses_without_block = "warn" end
    assert_equal :raise, config.responses_without_block
  end

  test ".default" do
    default = Config.default
    assert default.equal?(Config.default)
    assert default.is_a?(Config)
    assert default.frozen?
    refute default.debug?
  end

  test ".global" do
    global = Config.global
    assert global.equal?(Config.global)
    assert global.is_a?(Config)
    assert_same Config.default, global.parent
    assert_equal false, global.debug?
    global.debug = true
    assert_equal true, global.debug?
    global.reset(:debug)
    assert_equal false, global.debug?
    refute global.frozen?
  end

  test "Net::IMAP.config" do
    assert Net::IMAP.config.equal?(Config.global)
  end

  test ".new(parent, ...) and inheritance" do
    base = Config.new debug: false
    child = Config.new(base)
    assert_equal base, child.parent
    assert_equal false, child.debug
    assert_equal false, child.debug?
    base.debug = true
    assert_equal true, child.debug?
    child.debug = false
    assert_equal false, child.debug?
    child.reset(:debug)
    assert_equal true, child.debug?
    base.debug = false
    child.debug = true
    assert_equal true, child.debug?
    child = Config.new(base, debug: true)
    assert_equal true, child.debug?
    base.debug = true
    child = Config.new(base, debug: false)
    assert_equal false, child.debug?
  end

  test "#new and inheritance" do
    base = Config.new debug: false
    child = base.new
    assert_equal base, child.parent
    assert_equal false, child.debug
    assert_equal false, child.debug?
    base.debug = true
    assert_equal true, child.debug?
    child.debug = false
    assert_equal false, child.debug?
    child.reset(:debug)
    assert_equal true, child.debug?
    base.debug = false
    child.debug = true
    assert_equal true, child.debug?
    child = base.new(debug: true)
    assert_equal true, child.debug?
    base.debug = true
    child = base.new(debug: false)
    assert_equal false, child.debug?
  end

  test ".version_defaults are all frozen, and inherit debug from global" do
    Config.version_defaults.each do |name, config|
      assert [0, Float, Rational, Symbol].any? { _1 === name }
      assert_kind_of Config, config
      assert config.frozen?,            "#{name} isn't frozen"
      assert config.inherited?(:debug), "#{name} doesn't inherit debug"
      keys = config.to_h.keys - [:debug]
      keys.each do |key|
        refute config.inherited?(key)
      end
      assert_same Config.global, config.parent
    end
  end

  test "Config[:default] and Config[:current] both hold default config" do
    defaults = Config.default.to_h
    assert_equal(defaults, Config[:default].to_h)
    assert_equal(defaults, Config[:current].to_h)
  end

  test ".[] for all version_defaults" do
    Config.version_defaults.each do |version, config|
      assert_same Config[version], config
    end
  end

  test ".[] for all x.y versions" do
    original = Config[0r]
    assert_kind_of Config, original
    assert_same original, Config[0]
    assert_same original, Config[0.0]
    assert_same original, Config[0.1]
    assert_same original, Config[0.2]
    assert_same original, Config[0.3]
    ((0.4r..FUTURE_VERSION.to_r) % 0.1r).each do |version|
      config = Config[version]
      assert_kind_of Config, config
      assert_same config, Config[version.to_f]
      assert_same config, Config[version.to_f.to_r]
    end
  end

  test ".[] range errors" do
    assert_raise(RangeError) do Config[0.01] end
    assert_raise(RangeError) do Config[0.11] end
    assert_raise(RangeError) do Config[0.111] end
    assert_raise(RangeError) do Config[0.9] end
    assert_raise(RangeError) do Config[1] end
  end

  test ".[] key errors" do
    assert_raise(KeyError) do Config[:nonexistent] end
    assert_raise(KeyError) do Config["nonexistent"] end
    assert_raise(KeyError) do Config["0.01"] end
  end

  test ".[] with symbol names" do
    assert_equal   Config[THIS_VERSION].to_h, Config[:default].to_h
    assert_same    Config[THIS_VERSION],      Config[:current]
    assert_same    Config[NEXT_VERSION],      Config[:next]
    assert_same    Config[FUTURE_VERSION],    Config[:future]
  end

  test ".[] with string names" do
    assert_same Config[:original], Config["original"]
    assert_same Config[:current],  Config["current"]
    assert_same Config[0.4r],      Config["0.4.11"]
    assert_same Config[0.5r],      Config["0.5.6"]
    assert_same Config[:current],  Config[Net::IMAP::VERSION]
  end

  test ".[] with object responding to to_sym, to_r, or to_f" do
    # responds to none of the methods
    duck = Object.new
    assert_raise TypeError do Config[duck] end

    # to_sym
    duck = Object.new
    def duck.to_sym = :current
    assert_same Config[:current], Config[duck]

    # to_r
    duck = Object.new
    def duck.to_r = 0.6r
    assert_same Config[0.6r], Config[duck]

    # to_f
    duck = Object.new
    def duck.to_f = 0.4
    assert_same Config[0.4], Config[duck]

    # prefer to_r over to_f
    def duck.to_r   = 0.5r
    assert_same Config[0.5r], Config[duck]

    # prefer to_sym over to_r
    def duck.to_sym = :original
    assert_same Config[:original], Config[duck]

    # keeps trying if to_sym finds nothing
    duck = Object.new
    def duck.to_sym = :nope
    def duck.to_f   = 0.5
    assert_same Config[0.5],  Config[duck]
    # keeps trying if to_sym and to_r both find nothing
    def duck.to_r   = 1/11111
    assert_same Config[0.5],  Config[duck]
  end

  test ".[] with a hash" do
    config = Config[{responses_without_block: :raise, sasl_ir: false}]
    assert config.frozen?
    refute config.sasl_ir?
    assert config.inherited?(:debug)
    refute config.inherited?(:sasl_ir)
    assert_same Config.global, config.parent
    assert_same :raise, config.responses_without_block
  end

  test ".new always sets a parent" do
    assert_same Config.global,  Config.new.parent
    assert_same Config.default, Config.new(Config.default).parent
    assert_same Config.global,  Config.new(Config.global).parent
    assert_same Config[0.4],    Config.new(0.4).parent
    assert_same Config[NEXT_VERSION], Config.new(:next).parent
    assert_equal true, Config.new({debug: true}, debug: false).parent.debug?
    assert_equal true, Config.new({debug: true}, debug: false).parent.frozen?
  end

  test "#freeze" do
    config = Config.new(open_timeout: 1)
    config.freeze
    assert_raise FrozenError do
      config.open_timeout = 2
    end
    assert_same 1, config.open_timeout
  end

  test "#dup" do
    original = Config.new(open_timeout: 1)
    copy = original.dup
    refute_same original, copy
    copy.open_timeout = 2
    assert_equal 1, original.open_timeout
    assert_equal 2, copy.open_timeout

    original.freeze
    copy = original.dup
    refute copy.frozen?
    copy.open_timeout = 2
    assert_equal 2, copy.open_timeout
  end

  test "#clone" do
    original = Config.new(open_timeout: 1)
    copy = original.clone
    refute_same original, copy
    copy.open_timeout = 2
    assert_equal 1, original.open_timeout
    assert_equal 2, copy.open_timeout

    original.freeze
    copy = original.clone
    assert copy.frozen?
    assert_raise FrozenError do
      copy.open_timeout = 2
    end
    assert_equal 1, copy.open_timeout
  end

  test "#inherited? and #reset(attr)" do
    base = Config.new debug: false, open_timeout: 99, idle_response_timeout: 15
    child = base.new debug: true, open_timeout: 15, idle_response_timeout: 10
    refute child.inherited?(:idle_response_timeout)
    assert_equal 10, child.reset(:idle_response_timeout)
    assert child.inherited?(:idle_response_timeout)
    assert_equal 15, child.idle_response_timeout
    refute child.inherited?(:open_timeout)
    refute child.inherited?(:debug)
    child.debug = false
    refute child.inherited?(:debug)
    assert_equal false, child.reset(:debug)
    assert child.inherited?(:debug)
    assert_equal false, child.debug
    assert_equal nil, child.reset(:debug)
  end

  test "#reset all attributes" do
    base = Config.new debug: false, open_timeout: 99, idle_response_timeout: 15
    child = base.new debug: true, open_timeout: 15, idle_response_timeout: 10
    result = child.reset
    assert_same child, result
    assert child.inherited?(:debug)
    assert child.inherited?(:open_timeout)
    assert child.inherited?(:idle_response_timeout)
  end

  test "#to_h" do
    expected = {
      debug: false, open_timeout: 30, idle_response_timeout: 5, sasl_ir: true,
    }
    attributes = Config::AttrAccessors::Struct.members
    default_hash = Config.default.to_h
    assert_equal expected, default_hash.slice(*expected.keys)
    assert_equal attributes, default_hash.keys
    global_hash = Config.global.to_h
    assert_equal attributes, global_hash.keys
    assert_equal expected, global_hash.slice(*expected.keys)
  end

  test "#update" do
    config = Config.global.update(debug: true, sasl_ir: false, open_timeout: 2)
    assert_same Config.global, config
    assert_same true,  config.debug
    assert_same false, config.sasl_ir
    assert_same 2,     config.open_timeout
  end

  # It's simple to check first that the names are valid, so we do.
  test "#update with invalid key name" do
    config = Config.new(debug: true, sasl_ir: false, open_timeout: 2)
    assert_raise(ArgumentError) do
      config.update(debug: false, sasl_ir: true, bogus: :invalid)
    end
    assert_same true,  config.debug?
    assert_same false, config.sasl_ir?
    assert_same 2,     config.open_timeout
  end

  # Current behavior: partial updates are applied, in order they're received.
  # We could make #update atomic, but the complexity probably isn't worth it.
  test "#update with invalid value" do
    config = Config.new(debug: true, sasl_ir: false, open_timeout: 2)
    assert_raise(TypeError) do
      config.update(debug: false, open_timeout: :bogus, sasl_ir: true)
    end
    assert_same false, config.debug?       # updated
    assert_same 2,     config.open_timeout # unchanged
    assert_same false, config.sasl_ir?     # unchanged
  end

  test "#with" do
    orig = Config.new(open_timeout: 123, sasl_ir: false)
    assert_raise(ArgumentError) do
      orig.with
    end
    copy = orig.with(open_timeout: 456, idle_response_timeout: 789)
    refute copy.frozen?
    assert_same orig, copy.parent
    assert_equal 123, orig.open_timeout # unchanged
    assert_equal 456, copy.open_timeout
    assert_equal 789, copy.idle_response_timeout
    vals = nil
    result = orig.with(open_timeout: 99, idle_response_timeout: 88) do |c|
      vals = [c.open_timeout, c.idle_response_timeout, c.frozen?]
      :result
    end
    assert_equal :result, result
    assert_equal [99, 88, false], vals
    orig.freeze
    result = orig.with(open_timeout: 11) do |c|
      vals = [c.open_timeout, c.idle_response_timeout, c.frozen?]
    end
    assert_equal [11, 5, true], vals
  end

  test "#load_defaults" do
    config = Config.global.load_defaults 0.3
    assert_same Config.global, config
    assert_same true,  config.inherited?(:debug)
    assert_same false, config.inherited?(:sasl_ir)
    assert_same false, config.sasl_ir
    # does not _reset_ default
    config.debug = true
    Config.global.load_defaults 0.3
    assert_same false, config.inherited?(:debug)
    assert_same true,  config.debug?
    # does not change parent
    child           = Config.global.new
    grandchild      = child.new
    greatgrandchild = grandchild.new
    child.load_defaults :current
    grandchild.load_defaults :next
    greatgrandchild.load_defaults :future
    assert_same Config.global, child.parent
    assert_same child, grandchild.parent
    assert_same grandchild, greatgrandchild.parent
  end

  test "#max_response_size=(Integer | nil)" do
    config = Config.new

    config.max_response_size = 10_000
    assert_equal 10_000, config.max_response_size

    config.max_response_size = nil
    assert_nil config.max_response_size

    assert_raise(ArgumentError) do config.max_response_size = "invalid" end
    assert_raise(TypeError) do config.max_response_size = :invalid  end
  end

end
