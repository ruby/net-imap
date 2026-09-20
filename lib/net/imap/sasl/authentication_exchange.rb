# frozen_string_literal: true

module Net
  class IMAP
    module SASL

      # AuthenticationExchange is used internally by Net::IMAP#authenticate.
      # But the API is still *experimental*, and may change.
      #
      # * TODO: use with more clients, to verify the API can accommodate them.
      # * TODO: pass ClientAdapter#service to SASL.authenticator
      #
      # An AuthenticationExchange represents a single attempt to authenticate
      # a SASL client to a SASL server.  It is created from a client adapter, a
      # mechanism name, and a mechanism authenticator.  When #authenticate is
      # called, it will send the appropriate authenticate command to the server,
      # returning the client response on success and raising an exception on
      # failure.
      #
      # In most cases, the client will not need to use
      # SASL::AuthenticationExchange directly at all.  Instead, use
      # SASL::ClientAdapter#authenticate.  If customizations are needed, the
      # custom client adapter is probably the best place for that code.
      #
      #     def authenticate(...)
      #       MyClient::SASLAdapter.new(self).authenticate(...)
      #     end
      #
      # SASL::ClientAdapter#authenticate delegates to ::authenticate, like so:
      #
      #     def authenticate(...)
      #       sasl_adapter = MyClient::SASLAdapter.new(self)
      #       SASL::AuthenticationExchange.authenticate(sasl_adapter, ...)
      #     end
      #
      # ::authenticate simply delegates to ::build and #authenticate, like so:
      #
      #     def authenticate(...)
      #       sasl_adapter = MyClient::SASLAdapter.new(self)
      #       SASL::AuthenticationExchange
      #         .build(sasl_adapter, ...)
      #         .authenticate
      #     end
      #
      # And ::build delegates to SASL.authenticator and ::new, like so:
      #
      #     def authenticate(mechanism, ...)
      #       sasl_adapter = MyClient::SASLAdapter.new(self)
      #       authenticator = SASL.authenticator(mechanism, ...)
      #       SASL::AuthenticationExchange
      #         .new(sasl_adapter, mechanism, authenticator)
      #         .authenticate
      #     end
      #
      class AuthenticationExchange
        # Convenience method for <tt>build(...).authenticate</tt>
        #
        # See also: SASL::ClientAdapter#authenticate
        def self.authenticate(...) build(...).authenticate end

        # Convenience method to combine the creation of a new authenticator and
        # a new Authentication exchange.
        #
        # +client+ must be an instance of SASL::ClientAdapter.
        #
        # +mechanism+ must be a SASL mechanism name, as a string or symbol.
        #
        # +sasl_ir+ allows or disallows sending an "initial response", depending
        # also on whether the server capabilities, mechanism authenticator, and
        # client adapter all support it.  Defaults to +true+.
        #
        # +mechanism+, +args+, +kwargs+, and +block+ are all forwarded to
        # SASL.authenticator.  Use the +registry+ kwarg to override the global
        # SASL::Authenticators registry.
        def self.build(client, mechanism, *args, sasl_ir: true, **kwargs, &block)
          authenticator = SASL.authenticator(mechanism, *args, **kwargs, &block)
          new(client, mechanism, authenticator, sasl_ir: sasl_ir)
        end

        attr_reader :mechanism, :authenticator

        # An exception that has been raised by <tt>authenticator.process</tt>.
        attr_reader :process_error

        # An exception that represents an error response from the server.
        attr_reader :response_error

        def initialize(client, mechanism, authenticator, sasl_ir: true)
          @client = client
          @mechanism = Authenticators.normalize_name(mechanism)
          @authenticator = authenticator
          @sasl_ir = sasl_ir
          @processed = false
        end

        # Call #authenticate to execute an authentication exchange for #client
        # using #authenticator.  Authentication failures will raise an
        # exception.  Any exceptions other than AuthenticationCanceled or those
        # in <tt>client.response_errors</tt> will drop the connection.
        #
        # When <tt>authenticator.process</tt> raises any StandardError
        # (including AuthenticationCanceled), the authentication exchange will
        # be canceled before re-raising the exception.  The server will usually
        # respond with an error response, and the client will most likely raise
        # that error.  This client error will supercede the original error.
        # Unfortunately, the original error will not be the +#cause+ for the
        # client error.  But it will be available on #process_error.
        def authenticate
          handle_cancellation do
            client.run_command(mechanism, initial_response) { process _1 }
              .tap { raise process_error if process_error }
              .tap { raise AuthenticationIncomplete, _1 unless done? }
          end
        rescue AuthenticationCanceled, *client.response_errors
          raise # but don't drop the connection
        rescue
          client.drop_connection
          raise
        rescue Exception # rubocop:disable Lint/RescueException
          client.drop_connection!
          raise
        end

        def send_initial_response?
          @sasl_ir &&
            authenticator.respond_to?(:initial_response?) &&
            authenticator.initial_response? &&
            client.sasl_ir_capable? &&
            client.auth_capable?(mechanism)
        end

        def done?
          authenticator.respond_to?(:done?) ? authenticator.done? : @processed
        end

        private

        attr_reader :client

        def initial_response
          return unless send_initial_response?
          client.encode_ir authenticator.process nil
        end

        def process(challenge)
          @processed = true
          return client.cancel_response if process_error
          client.encode authenticator.process client.decode challenge
        rescue AuthenticationCanceled => error
          @process_error = error
          client.cancel_response
        rescue => error
          @process_error = begin
            raise AuthenticationError, "error while processing server challenge"
          rescue
            $!
          end
          client.cancel_response
        end

        # | process | response | => result                                |
        # |---------|----------|------------------------------------------|
        # | success | success  | success                                  |
        # | success | error    | reraise response error                   |
        # | error   | success  | raise incomplete error (cause = process) |
        # | error   | error    | raise canceled error   (cause = process) |
        def handle_cancellation
          result = begin
            yield
          rescue *client.response_errors => error
            @response_error = error
            raise unless process_error
          end
          raise_mutual_cancellation!       if process_error &&  response_error
          raise_incomplete_cancel!(result) if process_error && !response_error
          result
        end

        def raise_mutual_cancellation!
          raise process_error # sets the cause
        rescue
          raise AuthenticationCanceled.new(
            "authentication canceled (see error #cause and #response)",
            response: response_error
          )
        end

        def raise_incomplete_cancellation!
          raise process_error # sets the cause
        rescue
          raise AuthenticationIncomplete.new(
            response_error, "server ignored canceled authentication"
          )
        end

      end
    end
  end
end
