# frozen_string_literal: true

module Net::IMAP::SASL

  # Registry for SASL authenticators
  #
  # Registered authenticators must respond to +#new+ or +#call+ (e.g. a class or
  # a proc), receiving any credentials and options and returning an
  # authenticator instance. The returned object represents a single
  # authentication exchange and <em>must not</em> be reused for multiple
  # authentication attempts.
  #
  # An authenticator instance object must respond to +#process+, receiving the
  # server's challenge and returning the client's response.  Optionally, it may
  # also respond to +#initial_response?+ and +#done?+.  When
  # +#initial_response?+ returns +true+, +#process+ may be called the first
  # time with +nil+.  When +#done?+ returns +false+, the exchange is incomplete
  # and an exception should be raised if the exchange terminates prematurely.
  #
  # See the source for PlainAuthenticator, XOAuth2Authenticator, and
  # ScramSHA1Authenticator for examples.
  class Authenticators

    # Create a new Authenticators registry.
    #
    # This class is usually not instantiated directly.  Use SASL.authenticators
    # to reuse the default global registry.
    #
    # By default, the registry will be empty--without any registrations.  When
    # +add_defaults+ is +true+, authenticators for all standard mechanisms will
    # be registered.
    #
    def initialize(use_defaults: false)
      @authenticators = {}
      if use_defaults
        add_authenticator "OAuthBearer"
        add_authenticator "Plain"
        add_authenticator "XOAuth2"
        add_authenticator "Login"      # deprecated
        add_authenticator "Cram-MD5"   # deprecated
        add_authenticator "Digest-MD5" # deprecated
      end
    end

    # Returns the names of all registered SASL mechanisms.
    def names; @authenticators.keys end

    # :call-seq:
    #   add_authenticator(mechanism)
    #   add_authenticator(mechanism, authenticator_class)
    #   add_authenticator(mechanism, authenticator_proc)
    #
    # Registers an authenticator for #authenticator to use.  +mechanism+ is the
    # name of the
    # {SASL mechanism}[https://www.iana.org/assignments/sasl-mechanisms/sasl-mechanisms.xhtml]
    # implemented by +authenticator_class+ (for instance, <tt>"PLAIN"</tt>).
    #
    # If +mechanism+ refers to an existing authenticator, a warning will be
    # printed and the old authenticator will be replaced.
    #
    # When only a single argument is given, the authenticator class will be
    # lazily loaded from <tt>Net::IMAP::SASL::#{name}Authenticator</tt> (case is
    # preserved and non-alphanumeric characters are removed..
    def add_authenticator(name, authenticator = nil)
      key = name.upcase.to_sym
      authenticator ||= begin
        class_name = "#{name.gsub(/[^a-zA-Z0-9]/, "")}Authenticator".to_sym
        auth_class = nil
        ->(*creds, **props, &block) {
          auth_class ||= Net::IMAP::SASL.const_get(class_name)
          auth_class.new(*creds, **props, &block)
        }
      end
      @authenticators[key] = authenticator
    end

    # :call-seq:
    #   authenticator(mechanism, ...) -> auth_session
    #
    # Builds an authenticator instance using the authenticator registered to
    # +mechanism+.  The returned object represents a single authentication
    # exchange and <em>must not</em> be reused for multiple authentication
    # attempts.
    #
    # All arguments (except +mechanism+) are forwarded to the registered
    # authenticator's +#new+ or +#call+ method.  Each authenticator must
    # document its own arguments.
    #
    # [Note]
    #   This method is intended for internal use by connection protocol code
    #   only.  Protocol client users should see refer to their client's
    #   documentation, e.g. Net::IMAP#authenticate.
    def authenticator(mechanism, ...)
      auth = @authenticators.fetch(mechanism.upcase.to_sym) do
        raise ArgumentError, 'unknown auth type - "%s"' % mechanism
      end
      auth.respond_to?(:new) ? auth.new(...) : auth.call(...)
    end

  end

end
