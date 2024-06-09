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

end
