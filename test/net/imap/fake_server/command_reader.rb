# frozen_string_literal: true

require "net/imap"

class Net::IMAP::FakeServer

  class CommandReader
    attr_reader :last_command

    def initialize(socket)
      @socket = socket
      @last_comma0 = nil
    end

    def get_command
      buf = "".b
      while true
        s = socket.gets("\r\n") or break
        buf << s
        break unless /\{(\d+)(\+)?\}\r\n\z/n =~ buf
        $2 or socket.print "+ Continue\r\n"
        buf << socket.read(Integer($1))
      end
      @last_command = parse(buf)
    end

    private

    attr_reader :socket

    # TODO: convert bad command exception to tagged BAD response, when possible
    def parse(buf)
      /\A([^ ]+) ((?:UID )?\w+)(?: (.+))?\r\n\z/min =~ buf or
        raise "bad request: %p" [buf]
      case $2.upcase
      when "LOGIN", "SELECT", "EXAMINE", "ENABLE", "AUTHENTICATE"
        Command.new $1, $2, scan_astrings($3), buf
      else
        Command.new $1, $2, $3, buf # TODO...
      end
    end

    # TODO: this is not the correct regexp, and literals aren't handled either
    def scan_astrings(str)
      str
        .scan(/"((?:[^"\\]|\\["\\])+)"|(\S+)/n)
        .map {|quoted, astr| astr || quoted.gsub(/\\([\\"])/n, '\1') }
    end

  end
end
