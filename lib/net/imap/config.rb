# frozen_string_literal: true
# :markup: markdown

require_relative "config/attr_accessors"
require_relative "config/attr_inheritance"

module Net
  class IMAP

    # Net::IMAP::Config stores configuration options for Net::IMAP clients.
    #
    # ## Inheritance
    #
    # Configs have a parent[rdoc-ref:Config::AttrInheritance#parent] config, and
    # any attributes which have not been set locally will inherit the parent's
    # value.
    #
    # See the following methods, defined by Config::AttrInheritance:
    # - {#new}[rdoc-ref:Config::AttrInheritance#reset] -- create a new config
    #   which inherits from the receiver.
    # - {#inherited?}[rdoc-ref:Config::AttrInheritance#inherited?] -- return
    #   whether a particular attribute is inherited.
    # - {#reset}[rdoc-ref:Config::AttrInheritance#reset] -- reset attributes to
    #   be inherited.
    #
    # ## Thread Safety
    #
    # *NOTE:* Updates to config objects are not synchronized for thread-safety.
    #
    class Config
      # The default config, which is hardcoded and frozen.
      def self.default; @default end

      include AttrAccessors
      include AttrInheritance

      # The debug mode (boolean)
      #
      # | Starting with version | The default value is |
      # |-----------------------|----------------------|
      # | _original_            | +false+              |
      attr_accessor :debug
      alias debug? debug

      # Seconds to wait until a connection is opened.
      #
      # If the IMAP object cannot open a connection within this time,
      # it raises a Net::OpenTimeout exception.  See Net::IMAP.new.
      #
      # | Starting with version | The default value is |
      # |-----------------------|----------------------|
      # | _original_            | +30+ seconds         |
      attr_accessor :open_timeout

      # Seconds to wait until an IDLE response is received, after
      # the client asks to leave the IDLE state.  See Net::IMAP#idle_done.
      #
      # | Starting with version | The default value is |
      # |-----------------------|----------------------|
      # | _original_            | +5+ seconds          |
      attr_accessor :idle_response_timeout

      # Creates a new config object and initialize its attribute with +attrs+.
      #
      # If +parent+ is not given, the global config is used by default.
      #
      # If a block is given, the new config object is yielded to it.
      def initialize(parent = nil, **attrs)
        super(parent)
        attrs.each do send(:"#{_1}=", _2) end
        yield self if block_given?
      end

      @default = new(
        debug: false,
        open_timeout: 30,
        idle_response_timeout: 5,
      ).freeze

    end
  end
end
