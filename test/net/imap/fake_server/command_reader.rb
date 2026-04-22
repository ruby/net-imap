# frozen_string_literal: true

require "net/imap"

class Net::IMAP::FakeServer
  CommandParseError = RuntimeError

  class CommandReader
    attr_reader :last_command
    attr_accessor :literal_acceptor

    def initialize(socket)
      @socket = socket
      @last_command = nil
      @literal_acceptor = proc {|buff, size| true }
    end

    def get_command
      buf = "".b
      while true
        s = socket.gets("\r\n") or break
        buf << s
        break unless /\{(\d+)(\+)?\}\r\n\z/n =~ buf
        bytes = Integer($1)
        if $2
          buf << socket.read(bytes)
        elsif literal_acceptor[buf, bytes]
          socket.print "+ Continue\r\n"
          buf << socket.read(bytes)
        else
          partial = partial_parse(buf)
          socket.print "#{partial.tag} NO #{bytes} byte literal rejected\r\n"
          buf = "".b
        end
      end
      throw :eof if buf.empty?
      @last_command = parse(buf)
    rescue CommandParseError => err
      raise IOError, err.message if socket.eof? && !buf.end_with?("\r\n")
    end

    private

    attr_reader :socket

    # TODO: convert bad command exception to tagged BAD response, when possible
    def parse(buf)
      /\A([^ ]+) ((?:UID )?\w+)(?: (.+))?\r\n\z/min =~ buf or
        raise CommandParseError, "bad request: %p" [buf]
      case $2.upcase
      when "LOGIN", "SELECT", "EXAMINE", "ENABLE", "AUTHENTICATE"
        Command.new $1, $2, scan_astrings($3), buf
      else
        Command.new $1, $2, $3, buf # TODO...
      end
    end
    alias partial_parse parse

    # TODO: this is not the correct regexp, and literals aren't handled either
    def scan_astrings(str)
      str
        .scan(/"((?:[^"\\]|\\["\\])+)"|(\S+)/n)
        .map {|quoted, astr| astr || quoted.gsub(/\\([\\"])/n, '\1') }
    end

  end
end
