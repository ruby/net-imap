# frozen_string_literal: true

module Net
  class IMAP < Protocol
    module SASL

      # Authenticator for the "+EXTERNAL+" SASL mechanism, as specified by
      # RFC-4422[https://tools.ietf.org/html/rfc4422].  See
      # Net::IMAP#authenticate.
      #
      # The EXTERNAL mechanism requests that the server use client credentials
      # established external to SASL, for example by TLS certificate or IPsec.
      class ExternalAuthenticator

        # Authorization identity: an identity to act as or on behalf of.
        #
        # If not explicitly provided, the server defaults to using the identity
        # that was authenticated by the external credentials.
        attr_reader :authzid

        # :call-seq:
        #   new(authzid: nil, **) -> authenticator
        #
        # Creates an Authenticator for the "+EXTERNAL+" SASL mechanism, as
        # specified in RFC-4422[https://tools.ietf.org/html/rfc4422].  To use
        # this, see Net::IMAP#authenticate or your client's authentication
        # method.
        #
        # #authzid is an optional identity to act as or on behalf of.
        #
        # Any other keyword parameters are quietly ignored.
        def initialize(authzid: nil, **)
          @authzid = authzid&.to_str&.encode "UTF-8"
          if @authzid&.match?(/\u0000/u) # also validates UTF8 encoding
            raise ArgumentError, "contains NULL"
          end
          @done = false
        end

        # :call-seq:
        #   initial_response? -> true
        #
        # +EXTERNAL+ can send an initial client response.
        def initial_response?; true end

        # Returns #authzid, or an empty string if there is no authzid.
        def process(_)
          authzid || ""
        ensure
          @done = true
        end

        # Returns true when the initial client response was sent.
        #
        # The authentication should not succeed unless this returns true, but it
        # does *not* indicate success.
        def done?; @done end

      end
    end
  end
end
