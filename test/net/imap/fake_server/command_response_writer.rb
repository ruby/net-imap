# frozen_string_literal: true

require "net/imap"

class Net::IMAP::FakeServer

  class CommandResponseWriter < ResponseWriter
    attr_reader :command

    def initialize(parent, command)
      super(parent.socket, config: parent.config, state: parent.state)
      @command = command
    end

    def tag;  command.tag  end
    def name; command.name end
    def args; command.args end

    def tagged(cond, code:, text:)
      puts [tag, resp_cond(cond, text: text, code: code)].join(" ")
    end

    def done_ok(text = "#{name} done", code: nil)
      tagged :OK, text: text, code: code
    end

    def fail_bad(text = "Invalid command or args", code: nil)
      tagged :BAD, code: code, text: text
    end

    def fail_no(text, code: nil)
      tagged :NO, code: code, text: text
    end

    def fail_bad_state(state)
      fail_bad "Wrong state for command %s (%s)" % [name, state.name]
    end

    def fail_bad_args
      fail_bad "invalid args for #{name}"
    end

    def fail_no_command
      fail_no "%s command is not implemented" % [name]
    end

    private

  end
end
