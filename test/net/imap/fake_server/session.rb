# frozen_string_literal: true

class Net::IMAP::FakeServer
  # > "Session" refers to the sequence of client/server interaction from the
  # > time that a mailbox is selected (SELECT or EXAMINE command) until the time
  # > that selection ends (SELECT or EXAMINE of another mailbox, CLOSE command,
  # > UNSELECT command, or connection termination).
  # --- https://www.rfc-editor.org/rfc/rfc9051#name-conventions-used-in-this-do
  Session = Struct.new(:mbox, :args, keyword_init: true)
end
