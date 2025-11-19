# frozen_string_literal: true

require "net/imap"
require "test/unit"

class NumValidatorTest < Net::IMAP::TestCase
  NumValidator = Net::IMAP::NumValidator

  TEST_VALUES = {
    -1          => %i[invalid],

    0           => %i[number                              mod-sequence-valzer],
    1           => %i[number nz-number mod-sequence-value mod-sequence-valzer],
    0x0000_ffff => %i[number nz-number mod-sequence-value mod-sequence-valzer],
    0xffff_ffff => %i[number nz-number mod-sequence-value mod-sequence-valzer],
    0x0000_0001_0000_0000 => %i[       mod-sequence-value mod-sequence-valzer],
    0x0000_ffff_ffff_ffff => %i[       mod-sequence-value mod-sequence-valzer],
    0xffff_ffff_ffff_fffe => %i[       mod-sequence-value mod-sequence-valzer],

    0xffff_ffff_ffff_ffff => %i[invalid],
  }

  def self.using_test_values_for(type)
    TEST_VALUES.each do |value, types|
      label = value if value < 1
      label ||= "0x" + ("%016x" % value).chars.each_slice(4).map(&:join).join(?_)
      yield label, value, types.include?(type)
    end
  end

  using_test_values_for :number do |label, value, valid|
    test "#valid_number?(%s) => %p" % [label, valid] do
      assert_equal valid, NumValidator.valid_number?(value)
    end
  end

  using_test_values_for :"nz-number" do |label, value, valid|
    test "#valid_nz_number?(%s) => %p" % [label, valid] do
      assert_equal valid, NumValidator.valid_nz_number?(value)
    end
  end

  using_test_values_for :"mod-sequence-value" do |label, value, valid|
    test "#valid_mod_sequence_value?(%s) => %p" % [label, valid] do
      assert_equal valid, NumValidator.valid_mod_sequence_value?(value)
    end
  end

  using_test_values_for :"mod-sequence-valzer" do |label, value, valid|
    test "#valid_mod_sequence_valzer?(%s) => %p" % [label, valid] do
      assert_equal valid, NumValidator.valid_mod_sequence_valzer?(value)
    end
  end

  def assert_format_error
    assert_raise Net::IMAP::DataFormatError do
      yield
    end
  end

  using_test_values_for :number do |label, value, valid|
    result = valid ? "=> #{label}" : "raises DataFormatError"
    test "#ensure_number(%s) %s" % [label, result] do
      if valid
        assert_equal value, NumValidator.ensure_number(value)
      else
        assert_format_error do NumValidator.ensure_number(value) end
      end
    end
  end

  using_test_values_for :"nz-number" do |label, value, valid|
    result = valid ? "=> #{label}" : "raises DataFormatError"
    test "#ensure_nz_number(%s) %s" % [label, result] do
      if valid
        assert_equal value, NumValidator.ensure_nz_number(value)
      else
        assert_format_error do NumValidator.ensure_nz_number(value) end
      end
    end
  end

  using_test_values_for :"mod-sequence-value" do |label, value, valid|
    result = valid ? "=> #{label}" : "raises DataFormatError"
    test "#ensure_mod_sequence_value(%s) %s" % [label, result] do
      if valid
        assert_equal value, NumValidator.ensure_mod_sequence_value(value)
      else
        assert_format_error do NumValidator.ensure_mod_sequence_value(value) end
      end
    end
  end

  using_test_values_for :"mod-sequence-valzer" do |label, value, valid|
    result = valid ? "=> #{label}" : "raises DataFormatError"
    test "#ensure_mod_sequence_valzer(%s) %s" % [label, result] do
      if valid
        assert_equal value, NumValidator.ensure_mod_sequence_valzer(value)
      else
        assert_format_error do NumValidator.ensure_mod_sequence_valzer(value) end
      end
    end
  end

end
