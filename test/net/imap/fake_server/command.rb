# frozen_string_literal: true

require "net/imap"

class Net::IMAP::FakeServer
  Command = Struct.new(:tag, :name, :args, :raw)
end
