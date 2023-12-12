# frozen_string_literal: true

require "base64"

class Net::IMAP::FakeServer

  # :nodoc:
  class CommandRouter
    module Routable
      def on(*command_names, &handler)
        scope = self.is_a?(Module) ? self : singleton_class
        command_names.each do |command_name|
          scope.define_method("handle_#{command_name.downcase}", &handler)
        end
      end
    end

    include Routable
    extend  Routable

    def initialize(writer, config:, state:)
      @config = config
      @state  = state
      @writer = writer
    end

    def commands; state.commands end

    def handle(command)
      commands << command
      resp    = @writer.for_command(command)
      handler = handler_for(command) or return resp.fail_no_command
      handler.call(resp)
    end
    alias << handle

    def handler_for(command)
      hname = command.name.downcase.to_sym
      mname = :"handle_#{hname}"
      config.handlers[hname] || (method(mname) if respond_to?(mname))
    end

    on "CAPABILITY" do |resp|
      resp.args.nil? or return resp.fail_bad_args
      resp.untagged :CAPABILITY, state.capabilities(config)
      resp.done_ok
    end

    on "NOOP" do |resp|
      resp.args.nil? or return resp.fail_bad_args
      resp.done_ok
    end

    on "LOGOUT" do |resp|
      resp.args.nil? or return resp.fail_bad_args
      resp.bye
      state.logout
      begin
        resp.done_ok
      rescue IOError
        # TODO: fix whatever is causing this!
        warn "connection issue after bye but before LOGOUT could complete"
        if $!.respond_to? :detailed_message
          warn $!.detailed_message highlight: true, order: :bottom
        else
          warn $!.full_message     highlight: true, order: :bottom
        end
      end
    end

    on "STARTTLS" do |resp|
      state.tls? and return resp.fail_bad_args "TLS already established"
      state.not_authenticated? or return resp.fail_bad_state(state)
      resp.done_ok
      state.use_tls
    end

    on "LOGIN" do |resp|
      state.not_authenticated?           or return resp.fail_bad_state(state)
      args = resp.command.args
      args.count == 2                    or return resp.fail_bad_args
      username, password = args
      username == config.user[:username] or return resp.fail_no "wrong username"
      password == config.user[:password] or return resp.fail_no "wrong password"
      state.authenticate config.user
      resp.done_ok
    end

    on "AUTHENTICATE" do |resp|
      state.not_authenticated?           or return resp.fail_bad_state(state)
      args = resp.command.args
      (1..2) === args.length             or return resp.fail_bad_args
      args.first == "PLAIN"              or return resp.fail_no "unsupported"
      if args.length == 2
        response_b64 = args.last
      else
        response_b64 = resp.request_continuation("") || ""
        state.commands << {continuation: response_b64}
      end
      response = Base64.decode64(response_b64)
      response.empty?                   and return resp.fail_bad "canceled"
      # TODO: support mechanisms other than PLAIN.
      parts = response.split("\0")
      parts.length == 3                  or return resp.fail_bad "invalid"
      authzid, authcid, password = parts
      authzid  =  authcid if authzid.empty?
      authzid  == config.user[:username] or return resp.fail_no "wrong username"
      authcid  == config.user[:username] or return resp.fail_no "wrong username"
      password == config.user[:password] or return resp.fail_no "wrong password"
      state.authenticate config.user
      resp.done_ok
    end

    on "ENABLE" do |resp|
      state.authenticated? or return resp.fail_bad_state(state)
      resp.args&.any? or return resp.fail_bad_args
      enabled = (resp.args & config.capabilities_enablable) - state.enabled
      state.enabled.concat enabled
      resp.untagged :ENABLED, enabled
      resp.done_ok
    end

    # Will be used as defaults for mailboxes that haven't set their own values
    RFC3501_6_3_1_SELECT_EXAMPLE_DATA = {
      exists:             172,
      recent:               1,
      unseen:              12,
      uidvalidity: 3857529045,
      uidnext:           4392,

      flags:          %i[Answered Flagged Deleted Seen Draft].freeze,
      permanentflags: %i[Deleted Seen *].freeze,
    }.freeze

    def select_handler(command, resp)
      state.user or return resp.fail_bad_state(state)
      name, args = resp.args
      name or return resp.fail_bad_args
      name = name.upcase if name.to_s.casecmp? "inbox"
      mbox = config.mailboxes[name]
      mbox or return resp.fail_no "invalid mailbox %p" % [name]
      state.select mbox: mbox, args: args
      attrs = RFC3501_6_3_1_SELECT_EXAMPLE_DATA.merge mbox.to_h
      resp.untagged "%{exists} EXISTS" % attrs
      resp.untagged "%{recent} RECENT" % attrs
      resp.untagged "OK [UNSEEN %{unseen}] ..." % attrs
      resp.untagged "OK [UIDVALIDITY %{uidvalidity}] UIDs valid" % attrs
      resp.untagged "OK [UIDNEXT %{uidnext}] Predicted next UID" % attrs
      if mbox[:uidnotsticky]
        resp.untagged "NO [UIDNOTSTICKY] Non-persistent UIDs"
      end
      resp.untagged "FLAGS (%s)" % [flags(attrs[:flags])]
      resp.untagged "OK [PERMANENTFLAGS (%s)] Limited" % [
        flags(attrs[:permanentflags])
      ]
      code = command == "SELECT" ? "READ-WRITE" : "READ-ONLY"
      resp.done_ok code: code
    end

    on "SELECT"  do |resp| select_handler "SELECT",  resp end
    on "EXAMINE" do |resp| select_handler "EXAMINE", resp end

    on "CLOSE", "UNSELECT" do |resp|
      resp.args.nil? or return resp.fail_bad_args
      state.unselect
      resp.done_ok
    end

    private

    attr_reader :config, :state

    def flags(flags)
      flags.map { [Symbol === _1 ? "\\" : "", _1].join }.join(" ")
    end

  end
end

