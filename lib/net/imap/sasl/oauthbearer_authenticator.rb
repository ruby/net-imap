# frozen_string_literal: true

require_relative "gs2_header"

module Net
  class IMAP < Protocol
    module SASL

      # Abstract base class for the SASL mechanisms defined in
      # RFC7628[https://tools.ietf.org/html/rfc7628]:
      # * OAUTHBEARER[rdoc-ref:OAuthBearerAuthenticator]
      #   (OAuthBearerAuthenticator)
      # * OAUTH10A
      class OAuthAuthenticator
        include GS2Header

        # Authorization identity: an identity to act as or on behalf of.
        #
        # If no explicit authorization identity is provided, it is usually
        # derived from the authentication identity.  For the OAuth-based
        # mechanisms, the authentication identity is the identity established by
        # the OAuth credential.
        attr_reader :authzid

        # Hostname to which the client connected.
        attr_reader :host

        # Service port to which the client connected.
        attr_reader :port

        # HTTP method.  (optional)
        attr_reader :mthd

        # HTTP path data.  (optional)
        attr_reader :path

        # HTTP post data.  (optional)
        attr_reader :post

        # The query string.  (optional)
        attr_reader :qs

        # Stores the most recent server "challenge".  When authentication fails,
        # this may hold information about the failure reason, as JSON.
        attr_reader :last_server_response

        # Creates an RFC7628[https://tools.ietf.org/html/rfc7628] OAuth
        # authenticator.
        #
        # === Options
        #
        # See child classes for required configuration parameter(s).  The
        # following parameters are all optional, but protocols or servers may
        # add requirements for #authzid, #host, #port, or any other parameter.
        #
        # * #authzid ― Identity to act as or on behalf of.
        # * #host — Hostname to which the client connected.
        # * #port — Service port to which the client connected.
        # * #mthd — HTTP method
        # * #path — HTTP path data
        # * #post — HTTP post data
        # * #qs   — HTTP query string
        #
        def initialize(authzid: nil, host: nil, port: nil,
                       mthd: nil, path: nil, post: nil, qs: nil, **)
          @authzid = authzid
          @host    = host
          @port    = port
          @mthd    = mthd
          @path    = path
          @post    = post
          @qs      = qs
          @done    = false
        end

        # The {RFC7628 §3.1}[https://www.rfc-editor.org/rfc/rfc7628#section-3.1]
        # formatted response.
        def initial_client_response
          kv_pairs = {
            host: host, port: port, mthd: mthd, path: path, post: post, qs: qs,
            auth: authorization, # authorization is implemented by subclasses
          }.compact
          [gs2_header, *kv_pairs.map {|kv| kv.join("=") }, "\1"].join("\1")
        end

        # Returns initial_client_response the first time, then "<tt>^A</tt>".
        def process(data)
          @last_server_response = data
          done? ? "\1" : initial_client_response
        ensure
          @done = true
        end

        # Returns true when the initial client response was sent.
        #
        # The authentication should not succeed unless this returns true, but it
        # does *not* indicate success.
        def done?; @done end

        # Value of the HTTP Authorization header
        #
        # <b>Implemented by subclasses.</b>
        def authorization; raise "must be implemented by subclass" end

      end

      # Authenticator for the "+OAUTHBEARER+" SASL mechanism, specified in
      # RFC7628[https://tools.ietf.org/html/rfc7628].  Authenticates using OAuth
      # 2.0 bearer tokens, as described in
      # RFC6750[https://tools.ietf.org/html/rfc6750].  Use via
      # Net::IMAP#authenticate.
      #
      # RFC6750[https://tools.ietf.org/html/rfc6750] requires Transport Layer
      # Security (TLS) to secure the protocol interaction between the client and
      # the resource server.  TLS _MUST_ be used for +OAUTHBEARER+ to protect
      # the bearer token.
      class OAuthBearerAuthenticator < OAuthAuthenticator

        # An OAuth2 bearer token, generally the access token.
        attr_reader :oauth2_token

        # :call-seq:
        #   new(oauth2_token,  **options) -> authenticator
        #   new(oauth2_token:, **options) -> authenticator
        #
        # Creates an Authenticator for the "+OAUTHBEARER+" SASL mechanism.
        #
        # Called by Net::IMAP#authenticate and similar methods on other clients.
        #
        # === Options
        #
        # Only +oauth2_token+ is required by the mechanism, however protocols
        # and servers may add requirements for #authzid, #host, #port, or any
        # other parameter.
        #
        # * #oauth2_token — An OAuth2 bearer token or access token. *Required.*
        #   May be provided as either regular or keyword argument.
        # * #authzid ― Identity to act as or on behalf of.
        # * #host — Hostname to which the client connected.
        # * #port — Service port to which the client connected.
        # * See OAuthAuthenticator documentation for less common parameters.
        #
        def initialize(oauth2_token_arg = nil, oauth2_token: nil, **args, &blk)
          super(**args, &blk) # handles authzid, host, port, etc
          oauth2_token && oauth2_token_arg and
            raise ArgumentError, "conflicting values for oauth2_token"
          @oauth2_token = oauth2_token || oauth2_token_arg or
            raise ArgumentError, "missing oauth2_token"
        end

        # :call-seq:
        #   initial_response? -> true
        #
        # +OAUTHBEARER+ sends an initial client response.
        def initial_response?; true end

        # Value of the HTTP Authorization header
        def authorization; "Bearer #{oauth2_token}" end

      end
    end

  end
end
