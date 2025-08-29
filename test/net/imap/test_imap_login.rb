# frozen_string_literal: true

require "net/imap"
require "test/unit"
require_relative "fake_server"

class IMAPLoginTest < Net::IMAP::TestCase
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

  test "#login doesn't send CAPABILITY when it is already cached" do
    with_fake_server(
      preauth: false, cleartext_login: true, greeting_capabilities: true
    ) do |server, imap|
      imap.login("test_user", "test-password")
      cmd = server.commands.pop
      assert_equal "LOGIN", cmd.name
      assert_empty server.commands
    end
  end

  test "#login raises LoginDisabledError when LOGINDISABLED" do
    with_fake_server(preauth: false, cleartext_login: false) do |server, imap|
      assert imap.capabilities_cached?
      assert_raise(Net::IMAP::LoginDisabledError) do
        imap.login("test_user", "test-password")
      end
      assert_empty server.commands
    end
  end

  test "#login first checks capabilities for LOGINDISABLED (success)" do
    with_fake_server(
      preauth: false, cleartext_login: true, greeting_capabilities: false
    ) do |server, imap|
      imap.login("test_user", "test-password")
      cmd = server.commands.pop
      assert_equal "CAPABILITY", cmd.name
      cmd = server.commands.pop
      assert_equal "LOGIN", cmd.name
      assert_empty server.commands
    end
  end

  test "#login first checks capabilities for LOGINDISABLED (failure)" do
    with_fake_server(
      preauth: false, cleartext_login: false, greeting_capabilities: false
    ) do |server, imap|
      assert_raise(Net::IMAP::LoginDisabledError) do
        imap.login("test_user", "test-password")
      end
      cmd = server.commands.pop
      assert_equal "CAPABILITY", cmd.name
      assert_empty server.commands
    end
  end

  test("#login sends LOGIN without asking CAPABILITY " \
       "when config.enforce_logindisabled is false") do
    with_fake_server(
      preauth: false, cleartext_login: false, greeting_capabilities: false
    ) do |server, imap|
      imap.config.enforce_logindisabled = false
      imap.login("test_user", "test-password")
      cmd = server.commands.pop
      assert_equal "LOGIN", cmd.name
    end
  end

  test("#login raises LoginDisabledError without sending CAPABILITY " \
       "when config.enforce_logindisabled is :when_capabilities_cached") do
    with_fake_server(
      preauth: false, cleartext_login: false, greeting_capabilities: true
    ) do |server, imap|
      imap.config.enforce_logindisabled = :when_capabilities_cached
      assert_raise(Net::IMAP::LoginDisabledError) do
        imap.login("test_user", "test-password")
      end
      assert_empty server.commands
    end
  end

  test("#login sends LOGIN without asking CAPABILITY " \
       "when config.enforce_logindisabled is :when_capabilities_cached") do
    with_fake_server(
      preauth: false, cleartext_login: false, greeting_capabilities: false
    ) do |server, imap|
      imap.config.enforce_logindisabled = :when_capabilities_cached
      imap.login("test_user", "test-password")
      cmd = server.commands.pop
      assert_equal "LOGIN", cmd.name
      assert_empty server.commands
    end
    with_fake_server(
      preauth: false, cleartext_login: true, greeting_capabilities: true
    ) do |server, imap|
      imap.config.enforce_logindisabled = :when_capabilities_cached
      imap.login("test_user", "test-password")
      cmd = server.commands.pop
      assert_equal "LOGIN", cmd.name
      assert_empty server.commands
    end
  end

end
