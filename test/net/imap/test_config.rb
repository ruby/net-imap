# frozen_string_literal: true

require "net/imap"
require "test/unit"

class ConfigTest < Test::Unit::TestCase
  Config = Net::IMAP::Config

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

  test ".new always sets a parent" do
    assert_same Config.global,  Config.new.parent
    assert_same Config.default, Config.new(Config.default).parent
    assert_same Config.global,  Config.new(Config.global).parent
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

end
