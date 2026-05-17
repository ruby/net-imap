# frozen_string_literal: true

require "net/imap"
require "test/unit"

class NumValidatorTest < Net::IMAP::TestCase
  NumValidator = Net::IMAP::NumValidator

  TEST_VALUES = {
    -1          => %i[invalid],

    {"000"=> 0} => %i[number           number64                                mod-sequence-valzer],
    {"011"=>11} => %i[number           number64             mod-sequence-value mod-sequence-valzer],

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

  def self.each_integer_test_value_for(type)
    TEST_VALUES.each do |value, types|
      yield value, types.include?(type) if Integer === value
    end
  end

  def self.each_coercible_test_value_for(type)
    TEST_VALUES.each do |value, types|
      valid = types.include?(type)
      case value
      in Integer
        [value, value.to_s].each do |input|
          yield input, valid, value
        end
      in Hash if value.to_a in [[String => input, Integer => coerced]]
        yield input, valid, coerced
      end
    end
  end

  def self.each_num_validator_type_method(prefix, suffix = "")
    TYPES.each do |type|
      method_name = "#{prefix}_#{type}#{suffix}".tr(?-, ?_)
      yield type, method_name
    end
  end

  def self.test_method_invocation(method, input, result: nil, error: nil)
    label = ->(value) {
      case value
      in String                     then value.dump
      in true | false | nil         then value.to_s
      in Integer if value.negative? then value.to_s
      in Integer
        "0x" + ("%016x" % value).chars.each_slice(4).map(&:join).join(?_)
      end
    }
    if error
      test "#%s(%s) raises %s" % [method, label[input], error.name] do
        assert_raise error do NumValidator.public_send(method, input) end
      end
    else
      test "#%s(%s) => %s" % [method, label[input], label.(result)] do
        assert_equal result, NumValidator.public_send(method, input)
      end
    end
  end

  # Test valid_{type}?(input), e.g:
  #   #ensure_nz_number(0x0000_0000_ffff_ffff) => true
  #   #ensure_nz_number(0x0000_0001_0000_0000) => false
  each_num_validator_type_method(:valid, "?") do |type, method|
    each_integer_test_value_for type do |value, valid|
      test_method_invocation(method, value, result: valid)
    end
  end

  # Test ensure_{type}(input), e.g:
  #   #ensure_nz_number(0x0000_0000_ffff_ffff) => 0x0000_0000_ffff_ffff
  #   #ensure_nz_number(0x0000_0001_0000_0000) raises DataFormatError
  each_num_validator_type_method(:ensure) do |type, method|
    each_integer_test_value_for type do |value, valid|
      if valid
        test_method_invocation(method, value, result: value)
      else
        test_method_invocation(method, value, error: Net::IMAP::DataFormatError)
      end
    end
  end

  # Test coerce_{type}(input), e.g:
  #   #coerce_number64("9223372036854775807") => 9223372036854775807
  #   #coerce_number64("9223372036854775808") raises DataFormatError
  #   #coerce_number64(0x7fff_ffff_ffff_ffff) => 9223372036854775807
  #   #coerce_number64(0x8000_0000_0000_0000) raises DataFormatError
  each_num_validator_type_method(:coerce) do |type, method|
    each_coercible_test_value_for type do |value, valid, coerced|
      if valid
        test_method_invocation(method, value, result: coerced)
      else
        test_method_invocation(method, value, error: Net::IMAP::DataFormatError)
      end
    end
  end

end
