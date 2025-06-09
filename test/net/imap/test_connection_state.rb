# frozen_string_literal: true

require "net/imap"
require "test/unit"

class ConnectionStateTest < Net::IMAP::TestCase
  NotAuthenticated = Net::IMAP::ConnectionState::NotAuthenticated
  Authenticated    = Net::IMAP::ConnectionState::Authenticated
  Selected         = Net::IMAP::ConnectionState::Selected
  Logout           = Net::IMAP::ConnectionState::Logout

  test "#name" do
    assert_equal "not_authenticated", NotAuthenticated[].name
    assert_equal "authenticated",     Authenticated[]   .name
    assert_equal "selected",          Selected[]        .name
    assert_equal "logout",            Logout[]          .name
  end


  test "#to_sym" do
    assert_equal :not_authenticated, NotAuthenticated[].to_sym
    assert_equal :authenticated,     Authenticated[]   .to_sym
    assert_equal :selected,          Selected[]        .to_sym
    assert_equal :logout,            Logout[]          .to_sym
  end

  test "#deconstruct" do
    pend_if_truffleruby "TruffleRuby bug overriding ::Data methods" do
      assert_equal [:not_authenticated], NotAuthenticated[].deconstruct
      assert_equal [:authenticated],     Authenticated[]   .deconstruct
      assert_equal [:selected],          Selected[]        .deconstruct
      assert_equal [:logout],            Logout[]          .deconstruct
    end
  end

  test "#deconstruct_keys" do
    pend_if_truffleruby "TruffleRuby bug overriding ::Data methods" do
      assert_equal({symbol: :not_authenticated}, NotAuthenticated[].deconstruct_keys([:symbol]))
      assert_equal({symbol: :authenticated},     Authenticated[]   .deconstruct_keys([:symbol]))
      assert_equal({symbol: :selected},          Selected[]        .deconstruct_keys([:symbol]))
      assert_equal({symbol: :logout},            Logout[]          .deconstruct_keys([:symbol]))
      assert_equal({name: "not_authenticated"},  NotAuthenticated[].deconstruct_keys([:name]))
      assert_equal({name: "authenticated"},      Authenticated[]   .deconstruct_keys([:name]))
      assert_equal({name: "selected"},           Selected[]        .deconstruct_keys([:name]))
      assert_equal({name: "logout"},             Logout[]          .deconstruct_keys([:name]))
    end
  end

  test "#not_authenticated?" do
    assert_equal true,  NotAuthenticated[].not_authenticated?
    assert_equal false, Authenticated[]   .not_authenticated?
    assert_equal false, Selected[]        .not_authenticated?
    assert_equal false, Logout[]          .not_authenticated?
  end

  test "#authenticated?" do
    assert_equal false, NotAuthenticated[].authenticated?
    assert_equal true,  Authenticated[]   .authenticated?
    assert_equal false, Selected[]        .authenticated?
    assert_equal false, Logout[]          .authenticated?
  end

  test "#selected?" do
    assert_equal false, NotAuthenticated[].selected?
    assert_equal false, Authenticated[]   .selected?
    assert_equal true,  Selected[]        .selected?
    assert_equal false, Logout[]          .selected?
  end

  test "#logout?" do
    assert_equal false, NotAuthenticated[].logout?
    assert_equal false, Authenticated[]   .logout?
    assert_equal false, Selected[]        .logout?
    assert_equal true,  Logout[]          .logout?
  end

end


