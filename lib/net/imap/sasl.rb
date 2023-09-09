# frozen_string_literal: true

module Net
  class IMAP

    # Pluggable authentication mechanisms for protocols which support SASL
    # (Simple Authentication and Security Layer), such as IMAP4, SMTP, LDAP, and
    # XMPP.  {RFC-4422}[https://tools.ietf.org/html/rfc4422] specifies the
    # common SASL framework and the +EXTERNAL+ mechanism, and the
    # {SASL mechanism registry}[https://www.iana.org/assignments/sasl-mechanisms/sasl-mechanisms.xhtml]
    # lists the specification for others.
    #
    # "SASL is conceptually a framework that provides an abstraction layer
    # between protocols and mechanisms as illustrated in the following diagram."
    #
    #               SMTP    LDAP    XMPP   Other protocols ...
    #                  \       |    |      /
    #                   \      |    |     /
    #                  SASL abstraction layer
    #                   /      |    |     \
    #                  /       |    |      \
    #           EXTERNAL   GSSAPI  PLAIN   Other mechanisms ...
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

      def initial_response?(mechanism)
        mechanism.respond_to?(:initial_response?) && mechanism.initial_response?
      end

    end
  end

end
