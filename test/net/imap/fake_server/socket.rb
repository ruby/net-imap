# frozen_string_literal: true

class Net::IMAP::FakeServer

  # :nodoc:
  class Socket
    attr_reader :config
    attr_reader :tcp_socket, :tls_socket

    def initialize(tcp_socket, config:)
      @config     = config
      @tcp_socket = tcp_socket
      @tls_socket = nil
      @closed     = false
      use_tls if config.implicit_tls && tcp_socket
    end

    def tls?; !!@tls_socket end
    def closed?; @closed end

    def eof?;      socket.eof?       end
    def gets(...)  socket.gets(...)  end
    def read(...)  socket.read(...)  end
    def print(...) socket.print(...) end

    def use_tls
      @tls_socket ||= OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_ctx).tap do |s|
        s.sync_close = true
        s.accept
      end
    end

    def close
      @tls_socket&.close unless @tls_socket&.closed?
      @tcp_socket&.close unless @tcp_socket&.closed?
      @closed = true
    end

    private

    def socket; @tls_socket || @tcp_socket end

    def ssl_ctx
      @ssl_ctx ||= OpenSSL::SSL::SSLContext.new.tap do |ctx|
        ctx.ca_file = config.tls[:ca_file]
        ctx.key  = OpenSSL::PKey::RSA.new         File.read config.tls.fetch :key
        ctx.cert = OpenSSL::X509::Certificate.new File.read config.tls.fetch :cert
      end
    end

  end
end
