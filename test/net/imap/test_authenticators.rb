# frozen_string_literal: true

require "net/imap"
require "test/unit"

class AuthenticatorsTest < Net::IMAP::TestCase

  test "SASL::Authenticators.normalize_name" do
    authenticators = Net::IMAP::SASL::Authenticators
    assert_equal "FOO-BAR-BAZ", authenticators.normalize_name(:foo_bar_baz)
    assert_equal "SCRAM-SHA1-PLUS", authenticators.normalize_name(:scram_sha1_plus)
    assert_equal "PLAIN", authenticators.normalize_name("pLAin")
  end

  def test_net_imap_authenticator_deprecated
    assert_warn(/Net::IMAP\.authenticator .+deprecated./) do
      Net::IMAP.authenticator("PLAIN", "user", "pass")
    end
  end

  test ".authenticator mechanism name is case insensitive" do
    assert_kind_of(Net::IMAP::SASL::PlainAuthenticator,
                   Net::IMAP::SASL.authenticator("PLAIN", "user", "pass"))
    assert_kind_of(Net::IMAP::SASL::PlainAuthenticator,
                   Net::IMAP::SASL.authenticator("plain", "user", "pass"))
    assert_kind_of(Net::IMAP::SASL::PlainAuthenticator,
                   Net::IMAP::SASL.authenticator("pLaIn", "user", "pass"))
  end

  test ".authenticator mechanism name can be a symbol" do
    assert_kind_of(Net::IMAP::SASL::PlainAuthenticator,
                   Net::IMAP::SASL.authenticator(:PLAIN, "user", "pass"))
    assert_kind_of(Net::IMAP::SASL::PlainAuthenticator,
                   Net::IMAP::SASL.authenticator(:plain, "user", "pass"))
    assert_kind_of(Net::IMAP::SASL::PlainAuthenticator,
                   Net::IMAP::SASL.authenticator(:pLaIN, "user", "pass"))
  end

  # ----------------------
  # PLAIN
  # ----------------------

  def plain(...) Net::IMAP::SASL.authenticator("PLAIN", ...) end

  def test_plain_authenticator_matches_mechanism
    assert_kind_of(Net::IMAP::SASL::PlainAuthenticator, plain("user", "pass"))
  end

  def test_plain_supports_initial_response
    assert plain("foo", "bar").initial_response?
  end

  def test_plain_response
    assert_equal("\0authc\0passwd", plain("authc", "passwd").process(nil))
  end

  def test_plain_authzid
    assert_equal("authz\0user\0pass",
                 plain("user", "pass", authzid: "authz").process(nil))
  end

  def test_plain_kw_params
    assert_equal(
      "zid\0cid\0p",
      plain(authcid: "cid", password: "p", authzid: "zid").process(nil)
    )
    assert_equal(
      "zid\0cid\0p",
      plain(username: "cid", secret: "p", authzid: "zid").process(nil)
    )
  end

  def test_plain_username_kw_sets_both_authcid_and_authzid
    assert_equal(
      "\0uname\0passwd",
      plain(username: "uname", password: "passwd").process(nil)
    )
  end

  def test_plain_no_null_chars
    assert_raise(ArgumentError) { plain("bad\0user", "pass") }
    assert_raise(ArgumentError) { plain("user", "bad\0pass") }
    assert_raise(ArgumentError) { plain(authcid: "bad\0user", password: "p") }
    assert_raise(ArgumentError) { plain(username: "bad\0user", password: "p") }
    assert_raise(ArgumentError) { plain(username: "u", password: "bad\0pass") }
    assert_raise(ArgumentError) { plain("u", "p", authzid: "bad\0authz") }
    assert_raise(ArgumentError) { plain("u", "p", authzid: "bad\0authz") }
  end

  # ----------------------
  # OAUTHBEARER
  # ----------------------

  def test_oauthbearer_authenticator_matches_mechanism
    assert_kind_of(Net::IMAP::SASL::OAuthBearerAuthenticator,
                   Net::IMAP::SASL.authenticator("OAUTHBEARER", "tok"))
  end

  def oauthbearer(*args, **kwargs, &block)
    Net::IMAP::SASL.authenticator("OAUTHBEARER", *args, **kwargs, &block)
  end

  def test_oauthbearer_response
    assert_equal(
      "n,a=user@example.com,\1host=server.example.com\1port=587\1" \
      "auth=Bearer mF_9.B5f-4.1JqM\1\1",
      oauthbearer("mF_9.B5f-4.1JqM", authzid: "user@example.com",
                  host: "server.example.com", port: 587).process(nil)
    )
    assert_equal(
      "n,a=user@example.com,\1host=server.example.com\1port=587\1" \
      "auth=Bearer sssssssss\1\1",
      oauthbearer(secret: "sssssssss", username: "user@example.com",
                  host: "server.example.com", port: 587).process(nil)
    )
    assert_equal(
      "n,a=user,\1auth=Bearer tok\1\1", oauthbearer("user", "tok").process(nil)
    )
  end

  # ----------------------
  # SCRAM-SHA-1
  # SCRAM-SHA-256
  # SCRAM-SHA-* (etc)
  # ----------------------

  def test_scram_sha1_authenticator_matches_mechanism
    authenticator = Net::IMAP::SASL.authenticator("SCRAM-SHA-1", "user", "pass")
    assert_kind_of(Net::IMAP::SASL::ScramAuthenticator,     authenticator)
    assert_kind_of(Net::IMAP::SASL::ScramSHA1Authenticator, authenticator)
  end

  def test_scram_sha256_authenticator_matches_mechanism
    authenticator = Net::IMAP::SASL.authenticator("SCRAM-SHA-256", "user", "pass")
    assert_kind_of(Net::IMAP::SASL::ScramAuthenticator,       authenticator)
    assert_kind_of(Net::IMAP::SASL::ScramSHA256Authenticator, authenticator)
  end

  def scram_sha1(*args, **kwargs, &block)
    Net::IMAP::SASL.authenticator("SCRAM-SHA-1", *args, **kwargs, &block)
  end

  def scram_sha256(*args, **kwargs, &block)
    Net::IMAP::SASL.authenticator("SCRAM-SHA-256", *args, **kwargs, &block)
  end

  def test_scram_sha1_authenticator
    authenticator = scram_sha1("user", "pencil",
                               cnonce: "fyko+d2lbbFgONRv9qkxdawL")
    # n = no channel binding
    # a = authzid
    # n = authcid
    # r = random nonce (client)
    assert_equal("n,,n=user,r=fyko+d2lbbFgONRv9qkxdawL",
                 authenticator.process(nil))
    refute authenticator.done?
    assert_equal(
      # c = b64 of gs2 header and channel binding data
      # r = random nonce (client + server)
      # p = b64 client proof
      # s = salt
      # i = iteration count
      "c=biws," \
      "r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j," \
      "p=v0X8v3Bz2T0CJGbJQyF0X+HI4Ts=",
      authenticator.process(
        "r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j," \
        "s=QSXCR+Q6sek8bf92," \
        "i=4096")
    )
    refute authenticator.done?
    assert_empty authenticator.process("v=rmF9pqV8S7suAoZWja4dJRkFsKQ=")
    assert authenticator.done?
  end

  def test_scram_kwargs
    authenticator = scram_sha1(authcid: "user", password: "pass")
    assert_equal "user", authenticator.authcid
    assert_equal "pass", authenticator.password
    authenticator = scram_sha1(username: "user", secret: "pass")
    assert_equal "user", authenticator.authcid
    assert_equal "pass", authenticator.password
  end

  def test_scram_sha256_authenticator
    authenticator = scram_sha256("user", "pencil",
                                 cnonce: "rOprNGfwEbeRWgbNEkqO")
    # n = no channel binding
    # a = authzid
    # n = authcid
    # r = random nonce (client)
    assert_equal("n,,n=user,r=rOprNGfwEbeRWgbNEkqO",
                 authenticator.process(nil))
    refute authenticator.done?
    assert_equal(
      # c = b64 of gs2 header and channel binding data
      # r = random nonce (client + server)
      # p = b64 client proof
      # s = salt
      # i = iteration count
      "c=biws," \
      "r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0," \
      "p=dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ=",
      authenticator.process(
        "r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0," \
        "s=W22ZaJ0SNY7soEsUEjb6gQ==," \
        "i=4096")
    )
    refute authenticator.done?
    assert_empty authenticator.process(
      "v=6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4="
    )
    assert authenticator.done?
  end

  # ----------------------
  # XOAUTH2
  # ----------------------

  def xoauth2(...) Net::IMAP::SASL.authenticator("XOAUTH2", ...) end

  def test_xoauth2_authenticator_matches_mechanism
    assert_kind_of(Net::IMAP::SASL::XOAuth2Authenticator, xoauth2("user", "tok"))
  end

  def test_xoauth2_response
    assert_equal(
      "user=username\1auth=Bearer token\1\1",
      xoauth2("username", "token").process(nil)
    )
  end

  def test_xoauth2_kwargs
    assert_equal(
      "user=arg\1auth=Bearer kwarg\1\1",
      xoauth2("arg", oauth2_token: "kwarg").process(nil)
    )
    assert_equal(
      "user=user\1auth=Bearer kwarg\1\1",
      xoauth2(username: "user", oauth2_token: "kwarg").process(nil)
    )
    assert_equal(
      "user=user\1auth=Bearer kwarg\1\1",
      xoauth2(authzid: "user", secret: "kwarg").process(nil)
    )
  end

  def test_xoauth2_supports_initial_response
    assert xoauth2("foo", "bar").initial_response?
  end

  # ----------------------
  # ANONYMOUS
  # ----------------------

  def anonymous(*args, **kwargs, &block)
    Net::IMAP::SASL.authenticator("ANONYMOUS", *args, **kwargs, &block)
  end

  def test_anonymous_matches_mechanism
    assert_kind_of(Net::IMAP::SASL::AnonymousAuthenticator, anonymous)
  end

  def test_anonymous_response
    assert_equal("", anonymous.process(nil))
    assert_equal("hello world", anonymous("hello world").process(nil))
    assert_equal("kwargs",
                 anonymous(anonymous_message: "kwargs").process(nil))
  end

  def test_anonymous_stringprep
    assert_raise(Net::IMAP::StringPrep::ProhibitedCodepoint) {
      anonymous("no\ncontrol\rchars").process(nil)
    }
    assert_raise(Net::IMAP::StringPrep::ProhibitedCodepoint) {
      anonymous("regional flags use tagging chars: e.g." \
                "🏴󠁧󠁢󠁥󠁮󠁧󠁿 England, " \
                "🏴󠁧󠁢󠁳󠁣󠁴󠁿 Scotland, " \
                "🏴󠁧󠁢󠁷󠁬󠁳󠁿 Wales.").process(nil)
    }
  end

  def test_anonymous_length_over_255
    assert_raise(ArgumentError) { anonymous("a" * 256).process(nil) }
  end

  # ----------------------
  # EXTERNAL
  # ----------------------

  def external(...)
    Net::IMAP::SASL.authenticator("EXTERNAL", ...)
  end

  def test_external_matches_mechanism
    assert_kind_of(Net::IMAP::SASL::ExternalAuthenticator, external)
  end

  def test_external_response
    assert_equal("", external.process(nil))
    assert_equal("", external.process(""))
    assert_equal("kwarg", external(authzid: "kwarg").process(nil))
    assert_equal("username", external(username: "username").process(nil))
    assert_equal("z", external("p", authzid: "z", username: "u").process(nil))
    assert_equal("positional", external("positional").process(nil))
  end

  def test_external_utf8
    assert_equal("", external.process(nil))
    assert_equal("🏴󠁧󠁢󠁥󠁮󠁧󠁿 England",
                 external(authzid: "🏴󠁧󠁢󠁥󠁮󠁧󠁿 England").process(nil))
  end

  def test_external_invalid
    assert_raise(ArgumentError) { external(authzid: "bad\0contains NULL") }
    assert_raise(ArgumentError) { external(authzid: "invalid utf8\x80") }
  end

  # ----------------------
  # LOGIN (obsolete)
  # ----------------------

  def login(*args, warn_deprecation: false, **kwargs, &block)
    Net::IMAP::SASL.authenticator(
      "LOGIN", *args, warn_deprecation: warn_deprecation, **kwargs, &block
    )
  end

  def test_login_authenticator_matches_mechanism
    assert_kind_of(Net::IMAP::SASL::LoginAuthenticator, login("n", "p"))
  end

  def test_login_does_not_support_initial_response
    refute login("foo", "bar").initial_response?
  end

  def test_login_authenticator_deprecated
    assert_warn(/LOGIN.+deprecated.+PLAIN/) do
      Net::IMAP::SASL.authenticator("LOGIN", "user", "pass")
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
    Net::IMAP::SASL.authenticator(
      "CRAM-MD5", *args, warn_deprecation: warn_deprecation, **kwargs, &block
    )
  end

  def test_cram_md5_authenticator_matches_mechanism
    assert_kind_of(Net::IMAP::SASL::CramMD5Authenticator, cram_md5("n", "p"))
  end

  def test_cram_md5_does_not_support_initial_response
    refute cram_md5("foo", "bar").initial_response?
  end

  def test_cram_md5_authenticator_deprecated
    assert_warn(/CRAM-MD5.+deprecated./) do
      Net::IMAP::SASL.authenticator("CRAM-MD5", "user", "pass")
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
    Net::IMAP::SASL.authenticator(
      "DIGEST-MD5", *args, warn_deprecation: warn_deprecation, **kwargs, &block
    )
  end

  def test_digest_md5_authenticator_matches_mechanism
    assert_kind_of(Net::IMAP::SASL::DigestMD5Authenticator,
                   digest_md5("n", "p", "z"))
  end

  def test_digest_md5_authenticator_deprecated
    assert_warn(/DIGEST-MD5.+deprecated.+RFC6331/) do
      Net::IMAP.authenticator("DIGEST-MD5", "user", "pass")
    end
  end

  def test_digest_md5_does_not_support_initial_response
    refute digest_md5("foo", "bar").initial_response?
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

  def test_digest_md5_authenticator_realm_and_digest_uri
    auth = digest_md5(authcid: "authc",
                      authzid: "authz",
                      password: "pass",
                      realm: "myrealm",
                      service: "smtp",
                      host: "mail.example.com",
                      service_name: "example.com")
    assert_match(
      %r{\A
        nonce="OA6MG9tEQGm2hh",
        username="authc",
        realm="myrealm",
        cnonce="[a-zA-Z0-9+/]{12,}={0,3}",
        digest-uri="smtp/mail\.example\.com/example\.com",
        qop="auth",
        maxbuf=65535,
        nc=00000001,
        charset=utf-8,
        authzid="authz",
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

  def test_digest_md5_authenticator_empty_challenge
    auth = digest_md5("user", "pass")
    assert_raise(Net::IMAP::DataFormatError) do
      auth.process("   ")
    end
  end

  def test_digest_md5_authenticator_empty_challenge_commas
    auth = digest_md5("user", "pass")
    assert_raise_with_message(Net::IMAP::DataFormatError, /empty challenge/i) do
      auth.process(" ,  ,  ")
    end
  end

  def test_digest_md5_authenticator_garbage_no_equal_sign
    auth = digest_md5("user", "pass")
    assert_raise_with_message(Net::IMAP::DataFormatError, /unparsable/i) do
      auth.process('nonce=required,algorithm=md5-sess,foo')
    end
  end

  def test_digest_md5_authenticator_qdstr_with_comma
    auth = digest_md5("user", "pass")
    assert_raise_with_message(Net::IMAP::DataFormatError, /unparsable/i) do
      auth.process('nonce=required,algorithm=md5-sess,.')
    end
  end

  def test_digest_md5_authenticator_garbage
    auth = digest_md5("user", "pass")
    assert_raise_with_message(Net::IMAP::DataFormatError, /unparsable/i) do
      auth.process('.')
    end
  end

  def test_digest_md5_authenticator_empty_qop
    auth = digest_md5("user", "pass")
    assert_raise_with_message(Net::IMAP::DataFormatError, /bad challenge/i) do
      auth.process('Qop=""')
    end
  end

  def test_digest_md5_authenticator_missing_nonce
    auth = digest_md5("user", "pass")
    assert_raise_with_message(Net::IMAP::DataFormatError, /didn't send nonce/i) do
      auth.process('Qop="auth"')
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
