# frozen_string_literal: true

module Net
  class IMAP
    module SASL

      # Caches salted_password, client_key, and server_key for
      # ScramAuthenticator, based on a specific #salt and #iterations.
      #
      # **NOTE:** <em>The cache object must be handled with the same level of
      # caution as the password itself.</em>  For example, it should always
      # be encrypted at rest.
      #
      # The server will most likely advertise the same +salt+ and +iterations+
      # upon reauthentication, so +client_key+ and +server_key+ (or just
      # +salted_password+) can usually replace the +password+ parameter to
      # ScramAuthenticator.
      #
      # Note that #read is <em>not thread-safe</em>.  Concurrent authentications
      # should dup or clone the cache object.
      ScramCache = Struct.new(
        :salt, :iterations,          # cache validity
        :salted_password,            # sufficient to generate keys
        :client_key, :server_key,    # sufficient to replace password
        keyword_init: true
      ) do
        # Returns whether the cache is able to be used as credentials, without
        # being recomputed from the password, assuming #salt and #iterations are
        # unchanged.
        def sufficient?
          salt && iterations && (client_key && server_key || salted_password)
        end

        # Returns whether +salt+ and +iterations+ match cached values.
        def valid?(salt:, iterations:)
          salt       in String  or raise Error, "unknown salt"
          iterations in Integer or raise Error, "unknown iterations"
          self.salt == salt && self.iterations == iterations
        end

        # Reset cached values when +salt+ and +iterations+ do not match.
        def validate!(**) = valid?(**) || reset(**)

        # After validating +salt+ and +iterations+, either returns the cached
        # value for +name+ or yields to recompute and cache +name+.
        def read(name, **)
          raise ArgumentError, "missing required block" unless block_given?
          validate!(**)
          self[name] ||= yield
        end

        # Reset #salt, #iterations, and all cached fields.
        def reset(salt: nil, iterations: nil)
          {salt:, iterations:} => {salt: String, iterations: Integer} |
                                  {salt: nil,    iterations: nil    }
          self.salted_password = self.client_key = self.server_key = nil
          self.salt            = salt
          self.iterations      = iterations
          self
        end
      end

    end
  end
end
