# frozen_string_literal: true

require "openssl"
require "securerandom"

require_relative "gs2_header"
require_relative "scram_algorithm"
require_relative "scram_cache"

module Net
  class IMAP
    module SASL

      # Abstract base class for the "+SCRAM-*+" family of SASL mechanisms,
      # defined in RFC5802[https://www.rfc-editor.org/rfc/rfc5802].  Use via
      # Net::IMAP#authenticate.
      #
      # Directly supported:
      # * +SCRAM-SHA-1+   --- ScramSHA1Authenticator
      # * +SCRAM-SHA-256+ --- ScramSHA256Authenticator
      #
      # New +SCRAM-*+ mechanisms can easily be added for any hash algorithm
      # supported by
      # OpenSSL::Digest[https://ruby.github.io/openssl/OpenSSL/Digest.html].
      # Subclasses need only set an appropriate +DIGEST_NAME+ constant.
      #
      # === SCRAM algorithm
      #
      # See the documentation and method definitions on ScramAlgorithm for an
      # overview of the algorithm.  The different mechanisms differ only by
      # which hash function that is used (or by support for channel binding with
      # +-PLUS+).
      #
      # See also the methods on GS2Header.
      #
      # ==== Server messages
      #
      # As server messages are received, they are validated and loaded into
      # the various attributes, e.g: #snonce, #salt, #iterations, #verifier,
      # #server_error, etc.
      #
      # Unlike many other SASL mechanisms, the +SCRAM-*+ family supports mutual
      # authentication and can return server error data in the server messages.
      # If #process raises an Error for the server-final-message, then
      # server_error may contain error details.
      #
      # === TLS Channel binding
      #
      # <em>The <tt>SCRAM-*-PLUS</tt> mechanisms and channel binding are not
      # supported yet.</em>
      #
      # === Caching SCRAM secrets
      #
      # The values for salted_password, client_key, and server_key are stored in
      # #cache, a SASL::ScramCache object.  This object can be saved and re-used
      # across multiple authentication exchanges.  When the #salt and #iteration
      # are unchanged, the stored keys will be reused.  When they change, the
      # cache object is updated with the new values.
      #
      # **NOTE:** <em>The cache object must be handled with the same level of
      # caution as the password itself.</em>  For example, it should always
      # be encrypted at rest.
      #
      # When +cache+ contains the client and server keys (or the salted
      # password), +password+ is optional.  But authentication will fail if
      # #salt or #iterations change and #password hasn't been provided.
      #
      # Note that SASL::ScramCache is <em>not thread-safe</em>.  Concurrent
      # authentications should dup or clone the cache object.
      class ScramAuthenticator
        include GS2Header
        include ScramAlgorithm

        # :call-seq:
        #   new(username,  password,  **options) -> auth_ctx
        #   new(username:, password:, **options) -> auth_ctx
        #   new(authcid:,  password:, **options) -> auth_ctx
        #
        # Creates an authenticator for one of the "+SCRAM-*+" SASL mechanisms.
        # Each subclass defines #digest to match a specific mechanism.
        #
        # Called by Net::IMAP#authenticate and similar methods on other clients.
        #
        # === Parameters
        #
        # * #authcid  ― Identity whose #password is used.
        #
        #   #username - An alias for #authcid.
        # * #password ― Password or passphrase associated with this #username.
        # * _optional_ #cache - A pre-existing SASL::ScramCache object.
        # * _optional_ #authzid ― Alternate identity to act as or on behalf of.
        # * _optional_ #min_iterations - Overrides the default value (4096).
        # * _optional_ #max_iterations - Overrides the default value (2³¹ - 1).
        #
        # Any other keyword parameters are quietly ignored.
        #
        # *NOTE:* <em>It is the user's responsibility</em> to enforce minimum
        # and maximum iteration counts that are appropriate for their security
        # context.
        #
        # === Caching salted credentials
        #
        # When +cache+ contains the client and server keys (or the salted
        # password), +password+ is optional.
        #
        # See ScramAuthenticator@Caching+SCRAM+secrets and SASL::ScramCache.
        def initialize(username_arg = nil, password_arg = nil,
                       authcid: nil, username: nil,
                       authzid: nil,
                       password: nil, secret: nil,
                       min_iterations: 4096, # see both RFC5802 and RFC7677
                       max_iterations: 2**31 - 1,  # max int32
                       cnonce: nil, # must only be set in tests
                       cache: ScramCache.new,
                       **options)
          @username = username || username_arg || authcid or
            raise ArgumentError, "missing username (authcid)"
          cache => ScramCache
          @cache = cache
          @password = password || secret || password_arg
          @password || @cache.sufficient? or
            raise ArgumentError, "missing password"
          @authzid = authzid

          @min_iterations = Integer min_iterations
          @min_iterations.positive? or
            raise ArgumentError, "min_iterations must be positive"

          @max_iterations = Integer max_iterations.to_int
          @min_iterations <= @max_iterations or
            raise ArgumentError, "max_iterations must be more than min_iterations"

          @cnonce = cnonce || SecureRandom.base64(32)

          # These attrs are set from the server challenges
          @server_first_message = @snonce = @salt = @iterations = nil
          @server_error = nil

          # These values are created and cached in response to server challenges
          @client_first_message_bare = nil
          @client_final_message_without_proof = nil
        end

        # Authentication identity: the identity that matches the #password.
        #
        # RFC-2831[https://www.rfc-editor.org/rfc/rfc2831] uses the term
        # +username+.  "Authentication identity" is the generic term used by
        # RFC-4422[https://www.rfc-editor.org/rfc/rfc4422].
        # RFC-4616[https://www.rfc-editor.org/rfc/rfc4616] and many later RFCs
        # abbreviate this to +authcid+.
        attr_reader :username
        alias authcid username

        # A password or passphrase that matches the #username.
        attr_reader :password
        alias secret password

        # Authorization identity: an identity to act as or on behalf of.  The
        # identity form is application protocol specific.  If not provided or
        # left blank, the server derives an authorization identity from the
        # authentication identity.  For example, an administrator or superuser
        # might take on another role:
        #
        #     imap.authenticate "SCRAM-SHA-256", "root", passwd, authzid: "user"
        #
        # The server is responsible for verifying the client's credentials and
        # verifying that the identity it associates with the client's
        # authentication identity is allowed to act as (or on behalf of) the
        # authorization identity.
        attr_reader :authzid

        # The minimal allowed iteration count.  Lower #iterations will raise an
        # Error.
        #
        # *WARNING:* The default value (4096) is set to match guidance from
        # both {RFC5802}[https://www.rfc-editor.org/rfc/rfc5802#page-12]
        # and RFC7677[https://www.rfc-editor.org/rfc/rfc7677#section-4], but
        # {modern recommendations}[https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html#pbkdf2]
        # are significantly higher.
        #
        # It is ultimately the server's responsibility to securely store
        # password hashes.  While this parameter can alert the user to
        # insecure password storage and prevent insecure authentication
        # exchange, updating the iteration count generally requires resetting
        # the password on the server.
        attr_reader :min_iterations

        # The maximal allowed iteration count.  Higher #iterations will raise an
        # Error.
        #
        # As noted in {RFC5802}[https://www.rfc-editor.org/rfc/rfc5802#section-9]
        # >>>
        #   A hostile server can perform a computational denial-of-service
        #   attack on clients by sending a big iteration count value.
        #
        # *WARNING:* The default value is <tt>2³¹ - 1</tt>, the maximum signed
        # 32-bit integer.  This is large enough for the computation to take
        # several minutes, and insufficient protection against hostile servers.
        #
        # Note that <tt>OpenSSL::KDF.pbkdf2_hmac</tt> is implemented by a
        # blocking C function, and cannot be interrupted by +Timeout+ or
        # <tt>Thread.raise</tt>.  And it keeps the Global VM lock, as of v4.0 of
        # the +openssl+ gem, so other ruby threads will not be able to run.
        #
        # <em>To prevent a denial of service attack,</em> this must be set to a
        # safe value, depending on hardware and version of OpenSSL.  <em>It is
        # the user's responsibility</em> to enforce minimum and maximum
        # iteration counts that are appropriate for their security context.
        attr_reader :max_iterations

        # The client nonce, generated by SecureRandom
        attr_reader :cnonce

        # The server nonce, which must start with #cnonce
        attr_reader :snonce

        # The salt used by the server for this user
        attr_reader :salt

        # The iteration count for the selected hash function and user
        attr_reader :iterations

        # Caches salted_password, client_key, and server_key, based on a
        # specific #salt and #iterations.
        #
        # See SASL::ScramCache and ScramAuthenticator@Caching+SCRAM+secrets.
        attr_reader :cache

        # An error reported by the server during the \SASL exchange.
        #
        # Does not include errors reported by the protocol, e.g.
        # Net::IMAP::NoResponseError.
        attr_reader :server_error

        # Cached value for ScramAlgorithm#salted_password.
        # Requires +salt+ and +iterations+, from the server.
        def salted_password
          salted_cache_read(:salted_password) {
            password or raise Error, "invalid cache: salt or iteration changed"
            super
          }
        end

        # Cached value for ScramAlgorithm#client_key.
        # Requires +salt+ and +iterations+, from the server.
        def client_key = salted_cache_read(:client_key) { super }

        # Cached value for ScramAlgorithm#server_key.
        # Requires +salt+ and +iterations+, from the server.
        def server_key = salted_cache_read(:server_key) { super }

        # Returns a new OpenSSL::Digest object, set to the appropriate hash
        # function for the chosen mechanism.
        #
        # <em>The class's +DIGEST_NAME+ constant must be set to the name of an
        # algorithm supported by OpenSSL::Digest.</em>
        def digest; OpenSSL::Digest.new self.class::DIGEST_NAME end

        # See {RFC5802 §7}[https://www.rfc-editor.org/rfc/rfc5802#section-7]
        # +client-first-message+.
        def initial_client_response
          "#{gs2_header}#{client_first_message_bare}"
        end

        # responds to the server's challenges
        def process(challenge)
          case (@state ||= :initial_client_response)
          when :initial_client_response
            initial_client_response.tap { @state = :server_first_message }
          when :server_first_message
            recv_server_first_message challenge
            final_message_with_proof.tap { @state = :server_final_message }
          when :server_final_message
            recv_server_final_message challenge
            "".tap { @state = :done }
          else
            raise Error, "server sent after complete, %p" % [challenge]
          end
        rescue Exception => ex
          @state = ex
          raise
        end

        # Is the authentication exchange complete?
        #
        # If false, another server continuation is required.
        def done?; @state == :done end

        private

        def salted_cache_read(name)
          cache.read(name, salt:, iterations:) { yield }
        end

        # Need to store this for auth_message
        attr_reader :server_first_message

        def format_message(hash) hash.map { _1.join("=") }.join(",") end

        def recv_server_first_message(server_first_message)
          @server_first_message = server_first_message
          sparams = parse_challenge server_first_message
          @snonce = sparams["r"] or
            raise Error, "server did not send nonce"
          @salt = sparams["s"]&.unpack1("m") or
            raise Error, "server did not send salt"
          @iterations = sparams["i"]&.then {|i| Integer i } or
            raise Error, "server did not send iteration count"
          min_iterations <= iterations or
            raise Error, "too few iterations: %d" % [iterations]
          max_iterations.nil? || iterations <= max_iterations or
            raise Error, "too many iterations: %d" % [iterations]
          mext = sparams["m"] and
            raise Error, "mandatory extension: %p" % [mext]
          snonce.start_with? cnonce or
            raise Error, "invalid server nonce"
        end

        def recv_server_final_message(server_final_message)
          sparams = parse_challenge server_final_message
          @server_error = sparams["e"] and
            raise Error, "server error: %s" % [server_error]
          verifier = sparams["v"].unpack1("m") or
            raise Error, "server did not send verifier"
          verifier == server_signature or
            raise Error, "server verify failed: %p != %p" % [
              server_signature, verifier
            ]
        end

        # See {RFC5802 §7}[https://www.rfc-editor.org/rfc/rfc5802#section-7]
        # +client-first-message-bare+.
        def client_first_message_bare
          @client_first_message_bare ||=
            format_message(n: gs2_saslname_encode(SASL.saslprep(username)),
                           r: cnonce)
        end

        # See {RFC5802 §7}[https://www.rfc-editor.org/rfc/rfc5802#section-7]
        # +client-final-message+.
        def final_message_with_proof
          proof = [client_proof].pack("m0")
          "#{client_final_message_without_proof},p=#{proof}"
        end

        # See {RFC5802 §7}[https://www.rfc-editor.org/rfc/rfc5802#section-7]
        # +client-final-message-without-proof+.
        def client_final_message_without_proof
          @client_final_message_without_proof ||=
            format_message(c: [cbind_input].pack("m0"), # channel-binding
                           r: snonce)                   # nonce
        end

        # See {RFC5802 §7}[https://www.rfc-editor.org/rfc/rfc5802#section-7]
        # +cbind-input+.
        #
        # >>>
        #   *TODO:* implement channel binding, appending +cbind-data+ here.
        alias cbind_input gs2_header

        # RFC5802 specifies "that the order of attributes in client or server
        # messages is fixed, with the exception of extension attributes", but
        # this parses it simply as a hash, without respect to order.  Note that
        # repeated keys (violating the spec) will use the last value.
        def parse_challenge(challenge)
          challenge.split(/,/).to_h {|pair| pair.split(/=/, 2) }
        rescue ArgumentError
          raise Error, "unparsable challenge: %p" % [challenge]
        end

      end

      # Authenticator for the "+SCRAM-SHA-1+" SASL mechanism, defined in
      # RFC5802[https://www.rfc-editor.org/rfc/rfc5802].
      #
      # Uses the "SHA-1" digest algorithm from OpenSSL::Digest.
      #
      # See ScramAuthenticator.
      class ScramSHA1Authenticator < ScramAuthenticator
        DIGEST_NAME = "SHA1"
      end

      # Authenticator for the "+SCRAM-SHA-256+" SASL mechanism, defined in
      # RFC7677[https://www.rfc-editor.org/rfc/rfc7677].
      #
      # Uses the "SHA-256" digest algorithm from OpenSSL::Digest.
      #
      # See ScramAuthenticator.
      class ScramSHA256Authenticator < ScramAuthenticator
        DIGEST_NAME = "SHA256"
      end

    end
  end
end
