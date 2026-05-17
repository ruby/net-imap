# frozen_string_literal: true

require "net/imap"
require "test/unit"

class NumValidatorTest < Net::IMAP::TestCase
  NumValidator = Net::IMAP::NumValidator

  TEST_VALUES = {
    -1          => %i[invalid],

    0           => %i[number           number64                                mod-sequence-valzer],
    1           => %i[number nz-number number64 nz-number64 mod-sequence-value mod-sequence-valzer],
    0x0000_ffff => %i[number nz-number number64 nz-number64 mod-sequence-value mod-sequence-valzer],
    0xffff_ffff => %i[number nz-number number64 nz-number64 mod-sequence-value mod-sequence-valzer],
    0x0000_0001_0000_0000 => %i[       number64 nz-number64 mod-sequence-value mod-sequence-valzer],
    0x0000_ffff_ffff_ffff => %i[       number64 nz-number64 mod-sequence-value mod-sequence-valzer],
    0x7fff_ffff_ffff_ffff => %i[       number64 nz-number64 mod-sequence-value mod-sequence-valzer],
    0x8000_0000_0000_0000 => %i[                            mod-sequence-value mod-sequence-valzer],
    0xffff_ffff_ffff_fffe => %i[                            mod-sequence-value mod-sequence-valzer],

    0xffff_ffff_ffff_ffff => %i[invalid],
  }

  TYPES = TEST_VALUES.values.flatten.uniq - [:invalid]

  def self.each_test_value_for(type)
    TEST_VALUES.each do |value, types|
      label = value if value < 1
      label ||= "0x" + ("%016x" % value).chars.each_slice(4).map(&:join).join(?_)
      yield label, value, types.include?(type)
    end
  end

  def self.each_num_validator_type_method(prefix, suffix = "")
    TYPES.each do |type|
      method_name = "#{prefix}_#{type}#{suffix}".tr(?-, ?_)
      yield type, method_name
    end
  end

  # Test valid_{type}?(input), e.g:
  #   #ensure_nz_number(0x0000_0000_ffff_ffff) => true
  #   #ensure_nz_number(0x0000_0001_0000_0000) => false
  def self.define_test_for_valid_predicate(method, label, value, valid)
    test "#%s(%s) => %p" % [method, label, valid] do
      assert_equal valid, NumValidator.public_send(method, value)
    end
  end

  each_num_validator_type_method(:valid, "?") do |type, method|
    each_test_value_for type do |label, value, valid|
      define_test_for_valid_predicate(method, label, value, valid)
    end
  end

  def assert_format_error
    assert_raise Net::IMAP::DataFormatError do
      yield
    end
  end

  # Test ensure_{type}(input), e.g:
  #   #ensure_nz_number(0x0000_0000_ffff_ffff) => 0x0000_0000_ffff_ffff
  #   #ensure_nz_number(0x0000_0001_0000_0000) raises DataFormatError
  def self.define_test_for_ensure(method, label, value, valid)
    result = valid ? "=> #{label}" : "raises DataFormatError"
    test "#%s(%s) %s" % [method, label, result] do
      if valid
        assert_equal value, NumValidator.public_send(method, value)
      else
        assert_format_error do NumValidator.public_send(method, value) end
      end
    end
  end

  each_num_validator_type_method(:ensure) do |type, method|
    each_test_value_for type do |label, value, valid|
      define_test_for_ensure(method, label, value, valid)
    end
  end

  # Test coerce_{type}(input), e.g:
  #   #coerce_number64("9223372036854775807") => 9223372036854775807
  #   #coerce_number64("9223372036854775808") raises DataFormatError
  #   #coerce_number64(0x7fff_ffff_ffff_ffff) => 9223372036854775807
  #   #coerce_number64(0x8000_0000_0000_0000) raises DataFormatError
  def self.define_test_for_coerce(method, label, value, valid)
    result = valid ? "=> #{value}" : "raises DataFormatError"
    [value, value.to_s].each do |input|
      test "#%s(%p) %s" % [method, input, result] do
        if valid
          assert_equal value, NumValidator.public_send(method, input)
        else
          assert_format_error do NumValidator.public_send(method, input) end
        end
      end
    end
  end

  each_num_validator_type_method(:coerce) do |type, method|
    each_test_value_for type do |label, value, valid|
      define_test_for_coerce(method, label, value, valid)
    end
  end

end
