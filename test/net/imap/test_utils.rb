# frozen_string_literal: true

require "net/imap/utils"
require "test/unit"

class UtilsTest < Net::IMAP::TestCase
  include Net::IMAP::Utils

  test "#implicit_int" do
    assert_equal 0,    implicit_int(0)
    assert_equal(-123, implicit_int(-123))
    assert_equal 4567, implicit_int(4567)
    assert_equal 1,    implicit_int(1.23)

    int = Object.new
    def int.to_int = 890
    assert_equal 890, implicit_int(890)

    assert_implicit_integer_type_error do implicit_int(nil)        end
    assert_implicit_integer_type_error do implicit_int(true)       end
    assert_implicit_integer_type_error do implicit_int(false)      end
    assert_implicit_integer_type_error do implicit_int("123")      end
    assert_implicit_integer_type_error do implicit_int(:sym)       end
    assert_implicit_integer_type_error do implicit_int(Class)      end
    assert_implicit_integer_type_error do implicit_int(Object.new) end

    broken = Object.new
    def broken.to_int = :wat
    assert_raise(TypeError) do implicit_int(broken)  end
  end

end
