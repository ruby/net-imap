# frozen_string_literal: true

class Net::IMAP::FakeServer

  class ConnectionState
    Error = Class.new(RuntimeError)

    class InvalidStateChange < Error
      def initialize(msg = "invalid state change", *args, **change)
        msg = "%s: %p" % [msg, change] if change
        super(msg, *args)
      end
    end

    class AlreadyLoggedOut < InvalidStateChange
      def initialize(msg = "already logged out", *args)
        super(msg, *args)
      end
    end

    attr_reader :user
    attr_reader :session
    attr_reader :enabled
    attr_reader :commands

    def initialize(config:, socket: nil)
      @socket   = socket # for managing the TLS state
      @logout   = false
      @user     = nil
      @session  = nil
      @commands = Queue.new
      @enabled  = []

      if    config.preauth?     then authenticate config.user
      elsif config.greeting_bye then logout
      end
    end

    def capabilities(config)
      if    user then config.capabilities_post_auth
      elsif tls? then config.capabilities_pre_auth
      else            config.capabilities_pre_tls
      end
    end

    def tls?;    @socket.tls?    end
    def use_tls; @socket.use_tls end
    def closed?; @socket.closed? end

    def name
      if    @logout  then :logout
      elsif @session then :selected
      elsif @user    then :authenticated
      else                :not_authenticated
      end
    end

    def not_authenticated?; name == :not_authenticated end
    def authenticated?;     name == :authenticated     end
    def selected?;          name == :selected          end
    def logout?;            name == :logout            end

    def authenticate(user)
      not_authenticated? or raise InvalidStateChange, name => :authenticated
      user               or raise ArgumentError
      @user = user
    end

    def select(mbox:, **options)
      authenticated? || selected? or raise InvalidStateChange, name => :selected
      mbox                        or raise ArgumentError
      @session = Session.new mbox: mbox, **options
    end

    def unselect
      selected? or raise InvalidStateChange, selected: :authenticated
      @session = nil
    end

    def unauthenticate
      authenticated? || selected? or
        raise InvalidStateChange, name => :not_authenticated
      @user = @selected = nil
    end

    def logout
      !logout? or raise AlreadyLoggedOut
      @logout = true
    end

  end
end
