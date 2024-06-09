# frozen_string_literal: true
# :markup: markdown

require_relative "config/attr_accessors"

module Net
  class IMAP

    # Net::IMAP::Config stores configuration options for Net::IMAP clients.
    #
    # ## Thread Safety
    #
    # *NOTE:* Updates to config objects are not synchronized for thread-safety.
    #
    class Config
      # The default config, which is hardcoded and frozen.
      def self.default; @default end

      include AttrAccessors

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
      # If a block is given, the new config object is yielded to it.
      def initialize(**attrs)
        super()
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
