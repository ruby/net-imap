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
        buff = String.new
        catch :eof do
          while true
            read_line(buff)
            break unless /\{(\d+)\}\r\n\z/n =~ buff
            read_literal(buff, $1.to_i)
          end
        end
        buff
      end

      private

      def read_line(buff)
        buff << (@sock.gets(CRLF) or throw :eof)
      end

      def read_literal(buff, literal_size)
        literal = String.new(capacity: literal_size)
        buff << (@sock.read(literal_size, literal) or throw :eof)
      end

    end
  end
end
