# frozen_string_literal: true

require "net/imap"
require "test/unit"

class SASLScamCacheTest < Net::IMAP::TestCase
  SASL = Net::IMAP::SASL

  test "#sufficient?" do
    cache = SASL::ScramCache.new
    refute cache.sufficient?
    cache.salt       = "salt"
    cache.iterations = 5000
    refute cache.sufficient?
    cache.salted_password = "the-salted-password"
    assert cache.sufficient?

    cache.salted_password = nil
    cache.client_key = "the client key"
    refute cache.sufficient?
    cache.server_key = "the server key"
    assert cache.sufficient?
  end

  test "#validate!" do
    cache = SASL::ScramCache.new
    assert_raise(SASL::Error) { cache.validate!(salt: nil, iterations: nil) }
    assert_raise(SASL::Error) { cache.validate!(salt: "s", iterations: nil) }
    assert_raise(SASL::Error) { cache.validate!(salt: nil, iterations: 9999) }
    cache.salt = "s"
    cache.iterations = 9999
    cache.salted_password = "salted"
    cache.client_key = "ckey"
    cache.server_key = "skey"
    cache.validate!(salt: "different", iterations: 99_999)
    assert_equal "different", cache.salt
    assert_equal 99_999, cache.iterations
    assert_nil cache.salted_password
    assert_nil cache.client_key
    assert_nil cache.server_key
  end

  test "#read" do
    cache = SASL::ScramCache.new
    assert_raise(ArgumentError) { cache.read(:client_key) }
    assert_raise(ArgumentError) { cache.read(:client_key) { } }
    salt = iterations = nil
    assert_raise(SASL::Error) { cache.read(:client_key, salt:, iterations:) { } }

    salt, iterations = "salt1", 5000
    assert_equal "ck1", cache.read(:client_key, salt:, iterations:) { "ck1" }
    assert_equal "ck1", cache.client_key
    assert_equal "salt1", cache.salt
    assert_equal 5000, cache.iterations
    assert_equal "ck1", cache.read(:client_key, salt:, iterations:) { "update" }
    assert_equal "ck1", cache.client_key

    salt, iterations = "salt2", 9999
    assert_equal "ck2", cache.read(:client_key, salt:, iterations:) { "ck2" }
    assert_equal "ck2", cache.client_key
    assert_equal "salt2", cache.salt
    assert_equal 9999, cache.iterations

    assert_equal "sk", cache.read(:server_key, salt:, iterations:) { "sk" }
    assert cache.sufficient?
  end

end
