# frozen_string_literal: true

require "net/imap"
require "test/unit"

class NumValidatorTest < Net::IMAP::TestCase
  NumValidator = Net::IMAP::NumValidator

  test "#valid_number?" do
    refute NumValidator.valid_number?(-1)

    assert NumValidator.valid_number? 0
    assert NumValidator.valid_number? 1
    assert NumValidator.valid_number? 0x0000_ffff
    assert NumValidator.valid_number? 0xffff_ffff

    refute NumValidator.valid_number? 0x0000_0001_0000_0000
    refute NumValidator.valid_number? 0x0000_ffff_ffff_ffff
    refute NumValidator.valid_number? 0xffff_ffff_ffff_fffe
    refute NumValidator.valid_number? 0xffff_ffff_ffff_ffff
  end

  test "#valid_nz_number?" do
    refute NumValidator.valid_nz_number?(-1)
    refute NumValidator.valid_nz_number? 0

    assert NumValidator.valid_nz_number? 1
    assert NumValidator.valid_nz_number? 0x0000_0000_0000_ffff
    assert NumValidator.valid_nz_number? 0x0000_0000_ffff_ffff

    refute NumValidator.valid_nz_number? 0x0000_0001_0000_0000
    refute NumValidator.valid_nz_number? 0x0000_ffff_ffff_ffff
    refute NumValidator.valid_nz_number? 0xffff_ffff_ffff_fffe
    refute NumValidator.valid_nz_number? 0xffff_ffff_ffff_ffff
  end

  test "#valid_mod_sequence_value?" do
    refute NumValidator.valid_mod_sequence_value?(-1)
    refute NumValidator.valid_mod_sequence_value? 0

    assert NumValidator.valid_mod_sequence_value? 1
    assert NumValidator.valid_mod_sequence_value? 0x0000_0000_0000_ffff
    assert NumValidator.valid_mod_sequence_value? 0x0000_0000_ffff_ffff
    assert NumValidator.valid_mod_sequence_value? 0x0000_0001_0000_0000
    assert NumValidator.valid_mod_sequence_value? 0x0000_ffff_ffff_ffff
    assert NumValidator.valid_mod_sequence_value? 0xffff_ffff_ffff_fffe

    refute NumValidator.valid_mod_sequence_value? 0xffff_ffff_ffff_ffff
  end

  def assert_format_error
    assert_raise Net::IMAP::DataFormatError do
      yield
    end
  end

  test "#ensure_number" do
    assert_format_error do NumValidator.ensure_number(-1) end

    assert_equal 0x0000_0000, NumValidator.ensure_number(0x0000_0000)
    assert_equal 0x0000_0001, NumValidator.ensure_number(0x0000_0001)
    assert_equal 0x0000_ffff, NumValidator.ensure_number(0x0000_ffff)
    assert_equal 0xffff_ffff, NumValidator.ensure_number(0xffff_ffff)

    assert_format_error do NumValidator.ensure_number 0x0000_0001_0000_0000 end
    assert_format_error do NumValidator.ensure_number 0x0000_ffff_ffff_ffff end
    assert_format_error do NumValidator.ensure_number 0xffff_ffff_ffff_fffe end
    assert_format_error do NumValidator.ensure_number 0xffff_ffff_ffff_ffff end
  end

  test "#ensure_nz_number" do
    assert_format_error do NumValidator.ensure_nz_number(-1) end
    assert_format_error do NumValidator.ensure_nz_number 0   end

    assert_equal 0x0000_0001, NumValidator.ensure_nz_number(0x0000_0001)
    assert_equal 0x0000_ffff, NumValidator.ensure_nz_number(0x0000_ffff)
    assert_equal 0xffff_ffff, NumValidator.ensure_nz_number(0xffff_ffff)

    assert_format_error do NumValidator.ensure_nz_number 0x0000_0001_0000_0000 end
    assert_format_error do NumValidator.ensure_nz_number 0x0000_ffff_ffff_ffff end
    assert_format_error do NumValidator.ensure_nz_number 0xffff_ffff_ffff_fffe end
    assert_format_error do NumValidator.ensure_nz_number 0xffff_ffff_ffff_ffff end
  end

  test "#ensure_mod_sequence_value" do
    assert_format_error do NumValidator.ensure_mod_sequence_value(-1) end
    assert_format_error do NumValidator.ensure_mod_sequence_value 0   end

    assert_equal 0x0000_0001, NumValidator.ensure_mod_sequence_value(0x0000_0001)
    assert_equal 0x0000_ffff, NumValidator.ensure_mod_sequence_value(0x0000_ffff)
    assert_equal 0xffff_ffff, NumValidator.ensure_mod_sequence_value(0xffff_ffff)

    assert_equal 0x0000_0001_0000_0000,
      NumValidator.ensure_mod_sequence_value(0x0000_0001_0000_0000)
    assert_equal 0x0000_ffff_ffff_ffff,
      NumValidator.ensure_mod_sequence_value(0x0000_ffff_ffff_ffff)
    assert_equal 0xffff_ffff_ffff_fffe,
      NumValidator.ensure_mod_sequence_value(0xffff_ffff_ffff_fffe)

    assert_format_error do
      NumValidator.ensure_mod_sequence_value 0xffff_ffff_ffff_ffff
    end
  end

end
