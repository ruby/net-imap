# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class ConnectionStateTest < Test::Unit::TestCase
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
    # TODO: TruffleRuby's Data fails these
    assert_equal [:not_authenticated], NotAuthenticated[].deconstruct
    assert_equal [:authenticated],     Authenticated[]   .deconstruct
    assert_equal [:selected],          Selected[]        .deconstruct
    assert_equal [:logout],            Logout[]          .deconstruct
  end

  test "#deconstruct_keys" do
    # TODO: TruffleRuby's Data fails these
    assert_equal({symbol: :not_authenticated}, NotAuthenticated[].deconstruct_keys([:symbol]))
    assert_equal({symbol: :authenticated},     Authenticated[]   .deconstruct_keys([:symbol]))
    assert_equal({symbol: :selected},          Selected[]        .deconstruct_keys([:symbol]))
    assert_equal({symbol: :logout},            Logout[]          .deconstruct_keys([:symbol]))
    assert_equal({name: "not_authenticated"},  NotAuthenticated[].deconstruct_keys([:name]))
    assert_equal({name: "authenticated"},      Authenticated[]   .deconstruct_keys([:name]))
    assert_equal({name: "selected"},           Selected[]        .deconstruct_keys([:name]))
    assert_equal({name: "logout"},             Logout[]          .deconstruct_keys([:name]))
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

class IMAPConnectionStateTest < Test::Unit::TestCase
  include Net::IMAP::FakeServer::TestHelper

  def setup
    Net::IMAP.config.reset
    @do_not_reverse_lookup = Socket.do_not_reverse_lookup
    Socket.do_not_reverse_lookup = true
    @threads = []
  end

  def teardown
    if !@threads.empty?
      assert_join_threads(@threads)
    end
  ensure
    Socket.do_not_reverse_lookup = @do_not_reverse_lookup
  end

  test "#connection_state after AUTHENTICATE, SELECT, CLOSE successes" do
    with_fake_server(preauth: false) do |server, imap|
      # AUTHENTICATE, SELECT, CLOSE
      assert_equal :not_authenticated, imap.connection_state.to_sym
      imap.authenticate :plain, "test_user", "test-password"
      assert_equal :authenticated, imap.connection_state.to_sym
      imap.select "INBOX"
      assert_equal :selected, imap.connection_state.to_sym
      imap.close
      assert_equal :authenticated, imap.connection_state.to_sym
    end
  end

  test "#connection_state after LOGIN, EXAMINE, UNSELECT successes" do
    with_fake_server(preauth: false, cleartext_login: true) do |server, imap|
      assert_equal :not_authenticated, imap.connection_state.to_sym
      imap.login "test_user", "test-password"
      assert_equal :authenticated, imap.connection_state.to_sym
      imap.examine "INBOX"
      assert_equal :selected, imap.connection_state.to_sym
      imap.unselect
      assert_equal :authenticated, imap.connection_state.to_sym
    end
  end

  test "#connection_state after PREAUTH" do
    with_fake_server(preauth: true) do |server, imap|
      assert_equal :authenticated, imap.connection_state.to_sym
      imap.select "INBOX"
      assert_equal :selected, imap.connection_state.to_sym
      imap.unselect
      assert_equal :authenticated, imap.connection_state.to_sym
    end
  end

  test "#connection_state after [CLOSED] response code" do
    with_fake_server(select: "INBOX") do |server, imap|
      # NOOP doesn't _normally_ change the connection_state
      assert_equal :selected, imap.connection_state.to_sym
      server.on("NOOP", &:done_ok)
      imap.noop
      assert_equal :selected, imap.connection_state.to_sym

      # using NOOP to trigger the response code
      server.on("NOOP") do |resp|
        resp.untagged "OK", "[CLOSED] server maintenance"
        resp.done_ok
      end
      imap.noop
      assert_equal :authenticated, imap.connection_state.to_sym
    end
  end

  test "#connection_state after failed LOGIN or AUTHENTICATE" do
    with_fake_server(preauth: false, cleartext_login: false) do |server, imap|
      assert_raise(Net::IMAP::LoginDisabledError) do imap.login "foo", "bar" end
      assert_equal :not_authenticated, imap.connection_state.to_sym

      imap.config.enforce_logindisabled = false
      server.on "LOGIN"        do |cmd| cmd.fail_no "nope" end
      server.on "AUTHENTICATE" do |cmd| cmd.fail_no "nope" end

      assert_raise(Net::IMAP::NoResponseError) do
        imap.login "foo", "bar"
      end
      assert_equal :not_authenticated, imap.connection_state.to_sym

      assert_raise(Net::IMAP::NoResponseError) do
        imap.authenticate :plain, "foo", "bar"
      end
      assert_equal :not_authenticated, imap.connection_state.to_sym

      server.on "LOGIN"        do |cmd| cmd.fail_bad "bad!" end
      server.on "AUTHENTICATE" do |cmd| cmd.fail_bad "bad!" end

      assert_raise(Net::IMAP::BadResponseError) do
        imap.login "foo", "bar"
      end
      assert_equal :not_authenticated, imap.connection_state.to_sym

      assert_raise(Net::IMAP::BadResponseError) do
        imap.authenticate :plain, "foo", "bar"
      end
      assert_equal :not_authenticated, imap.connection_state.to_sym
    end
  end

  test "#connection_state after failed SELECT or EXAMINE" do
    with_fake_server(preauth: true) do |server, imap|
      # good SELECT to enter the :selected state
      imap.select "INBOX"
      assert_equal :selected, imap.connection_state.to_sym
      # bad SELECT enters the :authenticated state
      assert_raise(Net::IMAP::NoResponseError) do
        imap.select "doesn't exist"
      end
      assert_equal :authenticated, imap.connection_state.to_sym

      # back into the :selected state
      imap.examine "INBOX"
      assert_equal :selected, imap.connection_state.to_sym
      # bad EXAMINE enters the :authenticated state
      assert_raise(Net::IMAP::NoResponseError) do
        imap.examine "doesn't exist"
      end
      assert_equal :authenticated, imap.connection_state.to_sym
    end
  end

  test "#connection_state after #logout" do
    with_fake_server do |server, imap|
      imap.logout
      assert_equal :logout, imap.connection_state.to_sym
      imap.disconnect # avoid `logout!` warning and wait for closed socket
    end
  end

  test "#connection_state after #logout!" do
    with_fake_server do |server, imap|
      imap.logout!
      assert_equal :logout, imap.connection_state.to_sym
    end
  end

  test "#connection_state after #disconnect" do
    with_fake_server(ignore_io_error: true) do
      |server, imap|
      imap.disconnect
      assert_equal :logout, imap.connection_state.to_sym
    end
  end

end
