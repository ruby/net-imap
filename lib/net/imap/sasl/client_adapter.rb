# frozen_string_literal: true

module Net
  class IMAP
    module SASL

      # This API is *experimental*.
      #
      # TODO: catch exceptions in #process and send #cancel_response.
      # TODO: raise an error if the command succeeds after being canceled.
      # TODO: use with more clients, to verify the API can accommodate them.
      #
      # An abstract base class for implementing a SASL authentication exchange.
      # Different clients will each have their own adapter subclass, overridden
      # to match their needs.  Methods to override are documented as protected.
      class ClientAdapter
        # Subclasses must redefine this if their command isn't "AUTHENTICATE".
        COMMAND_NAME = "AUTHENTICATE"

        # Subclasses should redefine this to include all server responses errors
        # raised by send_command_with_continuations.
        RESPONSE_ERRORS = [].freeze

        # Convenience method for <tt>new(...).authenticate</tt>
        def self.authenticate(...) new(...).authenticate end

        attr_reader :client, :mechanism, :authenticator

        # Can be supplied by +client+, to avoid exposing private methods.
        attr_reader :command_proc

        # When +sasl_ir+ is false, sending an initial response is prohibited.
        # +command_proc+ can used to avoid exposing private methods on #client.
        def initialize(client, mechanism, authenticator, sasl_ir: true,
                       &command_proc)
          @client = client
          @mechanism = mechanism
          @authenticator = authenticator
          @sasl_ir = sasl_ir
          @command_proc = command_proc
        end

        # Call #authenticate to execute an authentication exchange for #client
        # using #authenticator.  Authentication failures will raise an
        # exception.  Any exceptions other than those in RESPONSE_ERRORS will
        # drop the connection.
        def authenticate
          response = process_ir if send_initial_response?
          args     = authenticate_command_args(response)
          send_command_with_continuations(*args) { process _1 }
            .tap { raise AuthenticationIncomplete, _1 unless done? }
        rescue *self.class::RESPONSE_ERRORS => ex
          raise transform_exception(ex)
        rescue => ex
          drop_connection
          raise transform_exception(ex)
        rescue Exception
          drop_connection!
          raise
        end

        protected

        # Override if the arguments for send_command_with_continuations aren't
        # simply <tt>(COMMAND_NAME, mechanism, initial_response = nil)</tt>.
        def authenticate_command_args(initial_response = nil)
          [self.class::COMMAND_NAME, mechanism, initial_response].compact
        end

        def encode_ir(string) string.empty? ? "=" : encode(string) end
        def encode(string)    [string].pack("m0") end
        def decode(string)    string.unpack1("m0") end
        def cancel_response;  "*" end

        # Override if the protocol always/never supports SASL-IR, the capability
        # isn't named +SASL-IR+, or #client doesn't respond to +capable?+.
        def supports_initial_response?; client.capable?("SASL-IR") end

        # Override if #client doesn't respond to +auth_capable?+.
        def supports_mechanism?; client.auth_capable?(mechanism) end

        # Runs the authenticate_command_args, yields each continuation payload,
        # responds to the server with the result of each yield, and returns the
        # result.  Non-successful results *MUST* raise an exception.  Exceptions
        # in the block *MUST* cause the command to fail.
        #
        # The default simply forwards all arguments to command_proc.
        # Subclasses that override this may use command_proc differently.
        def send_command_with_continuations(...)
          command_proc or raise Error, "initialize with block or override"
          command_proc.call(...)
        end

        # Override to logout and disconnect the connection gracefully.
        def drop_connection; client.disconnect end

        # Override to drop the connection abruptly.
        def drop_connection!; client.disconnect end

        # Override to transform any StandardError to a different exception.
        def transform_exception(exception) exception end

        private

        # Subclasses shouldn't override the following

        def send_initial_response?
          @sasl_ir &&
            authenticator.respond_to?(:initial_response?) &&
            authenticator.initial_response? &&
            supports_initial_response? &&
            supports_mechanism?
        end

        def process_ir;   encode_ir authenticator.process nil         end
        def process(data) encode    authenticator.process decode data end

        def done?; !authenticator.respond_to?(:done?) || authenticator.done? end

      end
    end
  end
end
