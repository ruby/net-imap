# frozen_string_literal: true

module Net
  class IMAP
    # See https://www.rfc-editor.org/rfc/rfc9051#section-2.2.2
    class ResponseReader # :nodoc:
      attr_reader :client

      def initialize(client, sock)
        @client, @sock = client, sock
      end

      def read_response_buffer
        @buff = String.new
        catch :eof do
          while true
            read_line
            break unless (@literal_size = get_literal_size)
            read_literal
          end
        end
        buff
      ensure
        @buff = nil
      end

      private

      attr_reader :buff, :literal_size

      def get_literal_size    = /\{(\d+)\}\r\n\z/n =~ buff && $1.to_i

      def read_line
        buff << (@sock.gets(CRLF) or throw :eof)
      end

      def read_literal
        literal = String.new(capacity: literal_size)
        buff << (@sock.read(literal_size, literal) or throw :eof)
      ensure
        @literal_size = nil
      end

    end
  end
end
