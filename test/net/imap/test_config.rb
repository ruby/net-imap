# frozen_string_literal: true

require "net/imap"
require "test/unit"

class ConfigTest < Test::Unit::TestCase
  Config = Net::IMAP::Config

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

  test ".default" do
    default = Config.default
    assert default.equal?(Config.default)
    assert default.is_a?(Config)
    assert default.frozen?
    refute default.debug?
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
