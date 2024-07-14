# frozen_string_literal: true

module Net
  class IMAP
    module SASL

      # This API is *experimental*, and may change.
      #
      # TODO: use with more clients, to verify the API can accommodate them.
      #
      # An abstract base class for implementing a SASL authentication exchange.
      # Different clients will each have their own adapter subclass, overridden
      # to match their needs.
      #
      # Although the default implementations _may_ be sufficient, subclasses
      # will probably need to override some methods.  Additionally, subclasses
      # may need to include a protocol adapter mixin, if the default
      # ProtocolAdapters::Generic isn't sufficient.
      class ClientAdapter
        include ProtocolAdapters::Generic

        # The client that handles communication with the protocol server.
        attr_reader :client

        # +command_proc+ can used to avoid exposing private methods on #client.
        # It's value is set by the block that is passed to ::new, and it is used
        # by the default implementation of #run_command.  Subclasses that
        # override #run_command may use #command_proc for any other purpose they
        # find useful.
        #
        # In the default implementation of #run_command, command_proc is called
        # with the protocols authenticate +command+ name, the +mechanism+ name,
        # an _optional_ +initial_response+ argument, and a +continuations+
        # block.  command_proc must run the protocol command with the arguments
        # sent to it, _yield_ the payload of each continuation, respond to the
        # continuation with the result of each _yield_, and _return_ the
        # command's successful result.  Non-successful results *MUST* raise
        # an exception.
        attr_reader :command_proc

        # By default, this simply sets the #client and #command_proc attributes.
        # Subclasses may override it, for example: to set the appropriate
        # command_proc automatically.
        def initialize(client, &command_proc)
          @client, @command_proc = client, command_proc
        end

        # Attempt to authenticate #client to the server.
        #
        # By default, this simply delegates to
        # AuthenticationExchange.authenticate.
        def authenticate(...) AuthenticationExchange.authenticate(self, ...) end

        # Do the protocol, server, and client all support an initial response?
        #
        # By default, this simply delegates to <tt>client.sasl_ir_capable?</tt>.
        def sasl_ir_capable?; client.sasl_ir_capable? end

        # Does the server advertise support for the mechanism?
        #
        # By default, this simply delegates to <tt>client.auth_capable?</tt>.
        def auth_capable?(mechanism); client.auth_capable?(mechanism) end

        # Calls command_proc with +command_name+ (see
        # SASL::ProtocolAdapters::Generic#command_name),
        # +mechanism+, +initial_response+, and a +continuations_handler+ block.
        # The +initial_response+ is optional; when it's nil, it won't be sent to
        # command_proc.
        #
        # Yields each continuation payload, responds to the server with the
        # result of each yield, and returns the result.  Non-successful results
        # *MUST* raise an exception.  Exceptions in the block *MUST* cause the
        # command to fail.
        #
        # Subclasses that override this may use #command_proc differently.
        def run_command(mechanism, initial_response = nil, &continuations_handler)
          command_proc or raise Error, "initialize with block or override"
          args = [command_name, mechanism, initial_response].compact
          command_proc.call(*args, &continuations_handler)
        end

        # The hostname to which the client connected.
        def host;             client.host end

        # The destination port to which the client connected.
        def port;             client.port end

        # Returns an array of server responses errors raised by run_command.
        # Exceptions in this array won't drop the connection.
        def response_errors; [] end

        # Drop the connection gracefully.
        #
        # By default, this simply delegates to <tt>client.drop_connection</tt>.
        def drop_connection;  client.drop_connection end

        # Drop the connection abruptly.
        #
        # By default, this simply delegates to <tt>client.drop_connection!</tt>.
        def drop_connection!; client.drop_connection! end
      end
    end
  end
end
