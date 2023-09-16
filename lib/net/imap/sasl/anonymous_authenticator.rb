# frozen_string_literal: true

module Net
  class IMAP < Protocol
    module SASL

      # Authenticator for the "+ANONYMOUS+" SASL mechanism, as specified by
      # RFC-4505[https://tools.ietf.org/html/rfc4505].  See
      # Net::IMAP#authenticate.
      class AnonymousAuthenticator

        # :call-seq:
        #   new(anonymous_message = "", **) -> authenticator
        #   new(anonymous_message:  "", **) -> authenticator
        #
        # Creates an Authenticator for the "+ANONYMOUS+" SASL mechanism, as
        # specified in RFC-4505[https://tools.ietf.org/html/rfc4505].  To use
        # this, see Net::IMAP#authenticate or your client's authentication
        # method.
        #
        # #anonymous_message is an optional message which is sent to the server.
        # It may be sent as a positional argument or as a keyword argument.
        #
        # Any other keyword parameters are quietly ignored.
        def initialize(anon_msg = nil, anonymous_message: nil, **)
          message = (anonymous_message || anon_msg || "").to_str
          @anonymous_message = StringPrep::Trace.stringprep_trace message
          if (size = @anonymous_message&.length)&.> 255
            raise ArgumentError,
                  "anonymous_message is too long.  (%d codepoints)" % [size]
          end
        end

        # A token sent for the +ANONYMOUS+ mechanism.
        #
        # If it contains an "@" sign, the message must be a valid email address
        # (+addr-spec+ from RFC-2822[https://tools.ietf.org/html/rfc2822]).
        # Email syntax is _not_ validated by AnonymousAuthenticator.
        #
        # Otherwise, it can be any UTF8 string which is permitted by the
        # StringPrep::Trace profile, up to 255 UTF-8 characters in length.
        attr_reader :anonymous_message

        # :call-seq:
        #   initial_response? -> true
        #
        # +ANONYMOUS+ can send an initial client response.
        def initial_response?; true end

        # Returns #anonymous_message.
        def process(_server_challenge_string) anonymous_message end

      end
    end
  end
end
