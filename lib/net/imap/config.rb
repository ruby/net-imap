# frozen_string_literal: true

require_relative "config/attr_accessors"
require_relative "config/attr_inheritance"
require_relative "config/attr_type_coercion"

module Net
  class IMAP

    # Net::IMAP::Config stores configuration options for Net::IMAP clients.
    # The global configuration can be seen at either Net::IMAP.config or
    # Net::IMAP::Config.global, and the client-specific configuration can be
    # seen at Net::IMAP#config.
    #
    # When creating a new client, all unhandled keyword arguments to
    # Net::IMAP.new are delegated to Config.new.  Every client has its own
    # config.
    #
    #   debug_client = Net::IMAP.new(hostname, debug: true)
    #   quiet_client = Net::IMAP.new(hostname, debug: false)
    #   debug_client.config.debug?  # => true
    #   quiet_client.config.debug?  # => false
    #
    # == Inheritance
    #
    # Configs have a parent[rdoc-ref:Config::AttrInheritance#parent] config, and
    # any attributes which have not been set locally will inherit the parent's
    # value.  Every client creates its own specific config.  By default, client
    # configs inherit from Config.global.
    #
    #   plain_client = Net::IMAP.new(hostname)
    #   debug_client = Net::IMAP.new(hostname, debug: true)
    #   quiet_client = Net::IMAP.new(hostname, debug: false)
    #
    #   plain_client.config.inherited?(:debug)  # => true
    #   debug_client.config.inherited?(:debug)  # => false
    #   quiet_client.config.inherited?(:debug)  # => false
    #
    #   plain_client.config.debug?  # => false
    #   debug_client.config.debug?  # => true
    #   quiet_client.config.debug?  # => false
    #
    #   # Net::IMAP.debug is delegated to Net::IMAP::Config.global.debug
    #   Net::IMAP.debug = true
    #   plain_client.config.debug?  # => true
    #   debug_client.config.debug?  # => true
    #   quiet_client.config.debug?  # => false
    #
    #   Net::IMAP.debug = false
    #   plain_client.config.debug = true
    #   plain_client.config.inherited?(:debug)  # => false
    #   plain_client.config.debug?  # => true
    #   plain_client.config.reset(:debug)
    #   plain_client.config.inherited?(:debug)  # => true
    #   plain_client.config.debug?  # => false
    #
    #
    # == Thread Safety
    #
    # *NOTE:* Updates to config objects are not synchronized for thread-safety.
    #
    class Config
      # The default config, which is hardcoded and frozen.
      def self.default; @default end

      # The global config object.  Also available from Net::IMAP.config.
      def self.global; @global end

      def self.[](config) # :nodoc: unfinished API
        if config.is_a?(Config) || config.nil? && global.nil?
          config
        else
          raise TypeError, "no implicit conversion of %s to %s" % [
            config.class, Config
          ]
        end
      end

      include AttrAccessors
      include AttrInheritance
      include AttrTypeCoercion

      # The debug mode (boolean)
      #
      # The default value is +false+.
      attr_accessor :debug, type: :boolean

      # method: debug?
      # :call-seq: debug? -> boolean
      #
      # Alias for #debug

      # Seconds to wait until a connection is opened.
      #
      # If the IMAP object cannot open a connection within this time,
      # it raises a Net::OpenTimeout exception.
      #
      # See Net::IMAP.new.
      #
      # The default value is +30+ seconds.
      attr_accessor :open_timeout, type: Integer

      # Seconds to wait until an IDLE response is received, after
      # the client asks to leave the IDLE state.
      #
      # See Net::IMAP#idle and Net::IMAP#idle_done.
      #
      # The default value is +5+ seconds.
      attr_accessor :idle_response_timeout, type: Integer

      # :markup: markdown
      #
      # Whether to use the +SASL-IR+ extension when the server and \SASL
      # mechanism both support it.
      #
      # See Net::IMAP#authenticate.
      #
      # | Starting with version | The default value is                     |
      # |-----------------------|------------------------------------------|
      # | _original_            | +false+ <em>(extension unsupported)</em> |
      # | v0.4                  | +true+  <em>(support added)</em>         |
      attr_accessor :sasl_ir, type: :boolean

      # :markup: markdown
      #
      # Controls the behavior of Net::IMAP#responses when called without a
      # block.  Valid options are `:warn`, `:raise`, or
      # `:silence_deprecation_warning`.
      #
      # | Starting with version   | The default value is           |
      # |-------------------------|--------------------------------|
      # | v0.4.13                 | +:silence_deprecation_warning+ |
      # | v0.5 <em>(planned)</em> | +:warn+                        |
      # | _eventually_            | +:raise+                       |
      attr_accessor :responses_without_block, type: [
        :silence_deprecation_warning, :warn, :raise,
      ]

      # Creates a new config object and initialize its attribute with +attrs+.
      #
      # If +parent+ is not given, the global config is used by default.
      #
      # If a block is given, the new config object is yielded to it.
      def initialize(parent = Config.global, **attrs)
        super(parent)
        attrs.each do send(:"#{_1}=", _2) end
        yield self if block_given?
      end

      @default = new(
        debug: false,
        open_timeout: 30,
        idle_response_timeout: 5,
        sasl_ir: true,
        responses_without_block: :silence_deprecation_warning,
      ).freeze

      @global = default.new

    end
  end
end
