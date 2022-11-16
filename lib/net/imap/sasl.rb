# frozen_string_literal: true

module Net
  class IMAP

    # Pluggable authentication mechanisms for protocols which support SASL
    # (Simple Authentication and Security Layer), such as IMAP4, SMTP, LDAP, and
    # XMPP.  {RFC-4422}[https://tools.ietf.org/html/rfc4422] specifies the
    # common \SASL framework:
    # >>>
    #   SASL is conceptually a framework that provides an abstraction layer
    #   between protocols and mechanisms as illustrated in the following
    #   diagram.
    #
    #               SMTP    LDAP    XMPP   Other protocols ...
    #                  \       |    |      /
    #                   \      |    |     /
    #                  SASL abstraction layer
    #                   /      |    |     \
    #                  /       |    |      \
    #           EXTERNAL   GSSAPI  PLAIN   Other mechanisms ...
    #
    # Net::IMAP uses SASL via the Net::IMAP#authenticate method.
    #
    # == Mechanisms
    #
    # Each mechanism has different properties and requirements.  Please consult
    # the documentation for the specific mechanisms you are using:
    #
    # +OAUTHBEARER+::
    #     See OAuthBearerAuthenticator.
    #
    #     Login using an OAuth2 Bearer token.  This is the standard mechanism
    #     for using OAuth2 with \SASL, but it is not yet deployed as widely as
    #     +XOAUTH2+.
    #
    # +PLAIN+::
    #     See PlainAuthenticator.
    #
    #     Login using clear-text username and password.
    #
    # +XOAUTH2+::
    #     See XOAuth2Authenticator.
    #
    #     Login using a username and an OAuth2 access token.  Non-standard and
    #     obsoleted by +OAUTHBEARER+, but widely supported.
    #
    # See the {SASL mechanism
    # registry}[https://www.iana.org/assignments/sasl-mechanisms/sasl-mechanisms.xhtml]
    # for a list of all SASL mechanisms and their specifications.  To register
    # new authenticators, see Authenticators.
    #
    # === Deprecated mechanisms
    #
    # <em>Obsolete mechanisms should be avoided, but are still available for
    # backwards compatibility.</em>
    #
    # >>>
    #   For +DIGEST-MD5+ see DigestMD5Authenticator.
    #
    #   For +LOGIN+, see LoginAuthenticator.
    #
    #   For +CRAM-MD5+, see CramMD5Authenticator.
    #
    # <em>Using a deprecated mechanism will print a warning.</em>
    #
    module SASL

      # autoloading to avoid loading all of the regexps when they aren't used.
      sasl_stringprep_rb = File.expand_path("sasl/stringprep", __dir__)
      autoload :StringPrep,          sasl_stringprep_rb
      autoload :SASLprep,            sasl_stringprep_rb
      autoload :StringPrepError,     sasl_stringprep_rb
      autoload :ProhibitedCodepoint, sasl_stringprep_rb
      autoload :BidiStringError,     sasl_stringprep_rb

      sasl_dir = File.expand_path("sasl", __dir__)
      autoload :Authenticators,           "#{sasl_dir}/authenticators"
      autoload :GS2Header,                "#{sasl_dir}/gs2_header"
      autoload :OAuthBearerAuthenticator, "#{sasl_dir}/oauthbearer_authenticator"
      autoload :PlainAuthenticator,       "#{sasl_dir}/plain_authenticator"
      autoload :XOAuth2Authenticator,     "#{sasl_dir}/xoauth2_authenticator"

      autoload :CramMD5Authenticator,     "#{sasl_dir}/cram_md5_authenticator"
      autoload :DigestMD5Authenticator,   "#{sasl_dir}/digest_md5_authenticator"
      autoload :LoginAuthenticator,       "#{sasl_dir}/login_authenticator"

      # Returns the default global SASL::Authenticators instance.
      def self.authenticators
        @authenticators ||= Authenticators.new(use_defaults: true)
      end

      # Delegates to ::authenticators.  See Authenticators#authenticator.
      def self.authenticator(...)     authenticators.authenticator(...) end

      # Delegates to ::authenticators.  See Authenticators#add_authenticator.
      def self.add_authenticator(...) authenticators.add_authenticator(...) end

      module_function

      # See Net::IMAP::StringPrep::SASLprep#saslprep.
      def saslprep(string, **opts)
        Net::IMAP::StringPrep::SASLprep.saslprep(string, **opts)
      end

      # Returns whether the authenticator is client-first and supports sending
      # an "initial response".
      def initial_response?(authenticator)
        authenticator.respond_to?(:initial_response?) &&
          authenticator.initial_response?
      end

    end
  end
end
