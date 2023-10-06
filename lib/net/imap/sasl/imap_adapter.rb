# frozen_string_literal: true

module Net
  class IMAP
    module SASL

      # Experimental
      class IMAPAdapter < ClientAdapter
        RESPONSE_ERRORS = [
          NoResponseError, BadResponseError, ByeResponseError
        ].freeze
        def supports_initial_response?; client.capable?("SASL-IR") end
        def supports_mechanism?;        client.auth_capable?(mechanism) end
        def drop_connection;            client.logout! end
      end
    end
  end
end
