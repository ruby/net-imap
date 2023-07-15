# frozen_string_literal: true
# shareable_constant_value: experimental_everything

class Net::IMAP::FakeServer

  # NOTE: The API is experimental and may change without deprecation or warning.
  #
  class Configuration
    CA_FILE     = File.expand_path("../../fixtures/cacert.pem", __dir__)
    SERVER_KEY  = File.expand_path("../../fixtures/server.key", __dir__)
    SERVER_CERT = File.expand_path("../../fixtures/server.crt", __dir__)

    DEFAULTS = {
      hostname: "localhost", port: 0,
      timeout: 10, connect_timeout: 2, read_timeout: 2, write_timeout: 2,

      implicit_tls: false,
      starttls: true,
      tls: { ca_file: CA_FILE, key: SERVER_KEY, cert: SERVER_CERT }.freeze,

      cleartext_login: false,
      encrypted_login: true,
      cleartext_auth:  false,
      sasl_mechanisms: %i[PLAIN].freeze,

      rev1: true,
      rev2: false,

      # TODO: use these to enable or disable actual commands
      extensions: %i[NAMESPACE MOVE IDLE UTF8=ACCEPT].freeze,

      capabilities_enablable: %i[UTF8=ACCEPT].freeze,

      preauth:               true,
      greeting_bye:          false,
      greeting_capabilities: true,
      greeting_text: "ruby Net::IMAP test server v#{Net::IMAP::VERSION}",

      user: {
        username: "test_user",
        password: "test-password",
      }.freeze,

      mailboxes: {
        "INBOX" => { name: "INBOX" }.freeze,
      }.freeze,
    }

    def initialize(with_extensions: [], without_extensions: [], **opts, &block)
      DEFAULTS.merge(opts).each do send :"#{_1}=", _2 end
      @handlers = {}
      self.extensions += with_extensions
      self.extensions -= without_extensions
      self.mailboxes = mailboxes.dup.transform_values(&:dup)
    end

    attr_reader :handlers
    attr_accessor(*DEFAULTS.keys)
    alias preauth?               preauth
    alias implicit_tls?          implicit_tls
    alias starttls?              starttls
    alias rev1?                  rev1
    alias rev2?                  rev2
    alias cleartext_login?       cleartext_login
    alias encrypted_login?       encrypted_login
    alias cleartext_auth?        cleartext_auth
    alias greeting_bye?          greeting_bye
    alias greeting_capabilities? greeting_capabilities

    def on(event, &handler)
      handler or raise ArgumentError
      handlers[event.to_sym.downcase] = handler
    end

    def greeting_cond; preauth? ? :PREAUTH : greeting_bye ? :BYE : :OK end

    def greeting_code
      return unless greeting_capabilities?
      capabilities =
        if preauth?         then capabilities_post_auth
        elsif implicit_tls? then capabilities_pre_auth
        else                     capabilities_pre_tls
        end
      [:CAPABILITY, *capabilities]
    end

    def auth_capabilities; sasl_mechanisms.map { "AUTH=#{_1}" } end

    def valid_username_and_password
      users
        .map  { _1.slice(:username, :password) }
        .find { _1.compact.length == 2 }
    end

    def basic_capabilities
      capa = []
      capa << "IMAP4rev1" if rev1?
      capa << "IMAP4rev2" if rev2?
      capa
    end

    def capabilities_pre_tls
      capa = basic_capabilities
      capa << "STARTTLS"            if starttls?
      capa << "LOGINDISABLED"   unless cleartext_login?
      capa.concat auth_capabilities if cleartext_auth?
      capa
    end

    def capabilities_pre_auth
      capa = basic_capabilities
      capa << "LOGINDISABLED" unless encrypted_login?
      capa.concat auth_capabilities
      capa
    end

    def capabilities_post_auth
      capa = basic_capabilities
      capa.concat extensions
      capa
    end

  end
end
