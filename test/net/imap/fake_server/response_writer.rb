# frozen_string_literal: true

require "net/imap"

class Net::IMAP::FakeServer

  # :nodoc:
  class ResponseWriter
    def initialize(socket, config:, state:)
      @socket = socket
      @config = config
      @state  = state
    end

    def for_command(command) CommandResponseWriter.new(self, command) end

    def request_continuation(message, length = nil)
      socket.print "+ #{message}\r\n" unless message.nil?
      length ? socket.read(Integer(length)) : socket.gets("\r\n")
    end

    def puts(*lines) lines.each do |msg| print "#{msg}\r\n" end end
    def print(...); socket.print(...) end

    def greeting
      untagged resp_cond(config.greeting_cond,
                         text: config.greeting_text,
                         code: config.greeting_code)
    end

    def bye(message = "Closing connection")
      untagged :BYE, message
    end

    def untagged(name_or_text, text = nil)
      puts [?*, name_or_text, text].compact.join(" ")
    end

    protected

    attr_reader :socket, :config, :state

    private

    def resp_code(code)
      case code
      in Array  then resp_code code.join(" ")
      in String then code.match?(/\A\[/) ? code : "[#{code}]"
      in nil    then nil
      end
    end

    def resp_cond(cond, text:, code: nil)
      case cond when :OK, :NO, :BAD, :BYE, :PREAUTH
        [cond, resp_code(code), text].compact.join " "
      else
        raise ArgumentError, "invalid resp-cond"
      end
    end

  end
end
