# frozen_string_literal: true

require "net/imap"
require "test/unit"

class IMAPAuthenticatorsTest < Test::Unit::TestCase

  # ----------------------
  # PLAIN
  # ----------------------

  def plain(...) Net::IMAP.authenticator("PLAIN", ...) end

  def test_plain_authenticator_matches_mechanism
    assert_kind_of(Net::IMAP::PlainAuthenticator, plain("user", "pass"))
  end

  def test_plain_supports_initial_response
    assert plain("foo", "bar").initial_response?
    assert Net::IMAP::SASL.initial_response?(plain("foo", "bar"))
  end

  def test_plain_response
    assert_equal("\0authc\0passwd", plain("authc", "passwd").process(nil))
    assert_equal("authz\0user\0pass",
                 plain("user", "pass", authzid: "authz").process(nil))
  end

  def test_plain_no_null_chars
    assert_raise(ArgumentError) { plain("bad\0user", "pass") }
    assert_raise(ArgumentError) { plain("user", "bad\0pass") }
    assert_raise(ArgumentError) { plain("u", "p", authzid: "bad\0authz") }
  end

  # ----------------------
  # XOAUTH2
  # ----------------------

  def xoauth2(...) Net::IMAP.authenticator("XOAUTH2", ...) end

  def test_xoauth2_authenticator_matches_mechanism
    assert_kind_of(Net::IMAP::XOauth2Authenticator, xoauth2("user", "pass"))
  end

  def test_xoauth2
    assert_equal(
      "user=username\1auth=Bearer token\1\1",
      xoauth2("username", "token").process(nil)
    )
  end

  def test_xoauth2_supports_initial_response
    assert xoauth2("foo", "bar").initial_response?
    assert Net::IMAP::SASL.initial_response?(xoauth2("foo", "bar"))
  end

  # ----------------------
  # LOGIN (obsolete)
  # ----------------------

  def login(*args, warn_deprecation: false, **kwargs, &block)
    Net::IMAP.authenticator(
      "LOGIN", *args, warn_deprecation: warn_deprecation, **kwargs, &block
    )
  end

  def test_login_authenticator_matches_mechanism
    assert_kind_of(Net::IMAP::LoginAuthenticator, login("n", "p"))
  end

  def test_login_does_not_support_initial_response
    refute Net::IMAP::SASL.initial_response?(login("foo", "bar"))
  end

  def test_login_authenticator_deprecated
    assert_warn(/LOGIN.+deprecated.+PLAIN/) do
      Net::IMAP.authenticator("LOGIN", "user", "pass")
    end
  end

  def test_login_responses
    auth_session = login("username", "password")
    assert_equal("username", auth_session.process("username?"))
    assert_equal("password", auth_session.process("password?"))
  end

  # ----------------------
  # CRAM-MD5 (obsolete)
  # ----------------------

  def cram_md5(*args, warn_deprecation: false, **kwargs, &block)
    Net::IMAP.authenticator(
      "CRAM-MD5", *args, warn_deprecation: warn_deprecation, **kwargs, &block
    )
  end

  def test_cram_md5_authenticator_matches_mechanism
    assert_kind_of(Net::IMAP::CramMD5Authenticator, cram_md5("n", "p"))
  end

  def test_cram_md5_does_not_support_initial_response
    refute Net::IMAP::SASL.initial_response?(cram_md5("foo", "bar"))
  end

  def test_cram_md5_authenticator_deprecated
    assert_warn(/CRAM-MD5.+deprecated./) do
      Net::IMAP.authenticator("CRAM-MD5", "user", "pass")
    end
  end

  def test_cram_md5_authenticator
    auth = cram_md5("username", "password")
    assert_match("username e2ce8ff3d1b914ddf339aa9f55198f86",
                 auth.process("fake-server-challence-string"))
  end

  # ----------------------
  # DIGEST-MD5 (obsolete)
  # ----------------------

  def digest_md5(*args, warn_deprecation: false, **kwargs, &block)
    Net::IMAP.authenticator(
      "DIGEST-MD5", *args, warn_deprecation: warn_deprecation, **kwargs, &block
    )
  end

  def test_digest_md5_authenticator_matches_mechanism
    assert_kind_of(Net::IMAP::DigestMD5Authenticator, digest_md5("n", "p", "z"))
  end

  def test_digest_md5_authenticator_deprecated
    assert_warn(/DIGEST-MD5.+deprecated.+RFC6331/) do
      Net::IMAP.authenticator("DIGEST-MD5", "user", "pass")
    end
  end

  def test_digest_md5_does_not_support_initial_response
    refute Net::IMAP::SASL.initial_response?(digest_md5("foo", "bar"))
  end

  def test_digest_md5_authenticator
    auth = digest_md5("cid", "password", "zid")
    assert_match(
      %r{\A
        nonce="OA6MG9tEQGm2hh",
        username="cid",
        realm="somerealm",
        cnonce="[a-zA-Z0-9+/]{12,}={0,3}", # RFC2831: >= 64 bits of entropy
        digest-uri="imap/somerealm",
        qop="auth",
        maxbuf=65535,
        nc=00000001,
        charset=utf-8,
        authzid="zid",
        response=[a-f0-9]+
      \Z}x,
      auth.process(
        %w[
          realm="somerealm"
          nonce="OA6MG9tEQGm2hh"
          qop="auth"
          charset=utf-8
          algorithm=md5-sess
        ].join(",")
      )
    )
  end

  def test_digest_md5_authenticator_garbage
    auth = digest_md5("user", "pass")
    assert_raise(Net::IMAP::DataFormatError) do
      auth.process('.')
    end
  end

  def test_digest_md5_authenticator_no_qop
    auth = digest_md5("user", "pass")
    assert_raise(Net::IMAP::DataFormatError) do
      auth.process('Qop=""')
    end
  end

  def test_digest_md5_authenticator_illinear
    pre = ->(n) {'qop="a' + ',x'*n}
    assert_linear_performance([5, 10, 15, 20], pre: pre) do |challenge|
      auth = digest_md5("user", "pass")
      assert_raise(Net::IMAP::DataFormatError) do
        auth.process(challenge)
      end
    end
  end
end
