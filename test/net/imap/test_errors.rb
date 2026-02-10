# frozen_string_literal: true

require "net/imap"
require "test/unit"

class IMAPErrorsTest < Net::IMAP::TestCase
  Token = Net::IMAP::ResponseParser::Token
  CSI = "\e["
  def self.CSI(*args) = CSI + args.join
  def self.SGR(*attr) = CSI attr.join(?;), ?m
  RESET          = SGR "" # could also use 0
  BOLD           = SGR 1
  BOLD_UNDERLINE = SGR 1, 4

  test "ResponseParseError" do
    # The first examples don't add parser state, so this makes no difference.
    # It affects the last example, which has parser state.
    Net::IMAP.debug = true

    name = Net::IMAP::ResponseParseError.name

    msg  = "unspecified parse error"
    err  = Net::IMAP::ResponseParseError.new
    assert_equal msg, err.message
    assert_equal Net::IMAP::ResponseParser, err.parser_class
    assert_nil err.string
    assert_nil err.pos
    assert_nil err.token
    assert_nil err.lex_state
    assert_equal("#{msg} (#{name})", err.detailed_message(parser_state: false))
    assert_equal("#{msg} (#{name})", err.detailed_message)
    assert_equal(
      "#{BOLD}#{msg} (#{BOLD_UNDERLINE}#{name}#{RESET}#{BOLD})#{RESET}",
      err.detailed_message(highlight: true)
    )

    msg = "unexpected ATOM (expected NSTRING)"
    err = Net::IMAP::ResponseParseError.new(msg)
    assert_equal msg, err.message
    assert_nil err.string
    assert_nil err.pos
    assert_nil err.token
    assert_nil err.lex_state
    assert_equal("#{msg} (#{name})", err.detailed_message(parser_state: false))
    assert_equal("#{msg} (#{name})", err.detailed_message)
    assert_equal(
      "#{BOLD}#{msg} (#{BOLD_UNDERLINE}#{name}#{RESET}#{BOLD})#{RESET}",
      err.detailed_message(highlight: true)
    )

    msg = "unexpected QUOTED (expected \"]\")"
    string = "tag OK [Error=\"Microsoft.Exchange.Error: foo\"] done\r\n"
    token  = Net::IMAP::ResponseParser::Token[:QUOTED, string[15, 29]]
    parser_state = [string, :EXPR_BEG, 45, token]
    err = Net::IMAP::ResponseParseError.new(msg, string:, parser_state:)
    assert_equal msg,       err.message
    assert_equal string,    err.string
    assert_equal 45,        err.pos
    assert_same  token,     err.token
    assert_equal :EXPR_BEG, err.lex_state
    assert_equal msg, err.message
    assert_equal("#{msg} (#{name})", err.detailed_message(parser_state: false))
    assert_equal(
      "#{BOLD}#{msg} (#{BOLD_UNDERLINE}#{name}#{RESET}#{BOLD})#{RESET}",
      err.detailed_message(highlight: true, parser_state: false)
    )
    assert_equal(<<~MSG.strip, err.detailed_message)
      #{msg} (#{name})
        processed : "tag OK [Error=\\"Microsoft.Exchange.Error: foo\\""
        remaining : "] done\\r\\n"
        pos       : 45
        lex_state : :EXPR_BEG
        token     : :QUOTED => "Microsoft.Exchange.Error: foo"
    MSG
    assert_equal(<<~MSG.strip, err.detailed_message(highlight: true))
      #{BOLD}#{msg} (#{BOLD_UNDERLINE}#{name}#{RESET}#{BOLD})#{RESET}
        processed : #{BOLD}"tag OK [Error=\\"Microsoft.Exchange.Error: foo\\""#{RESET}
        remaining : #{BOLD_UNDERLINE}"] done\\r\\n"#{RESET}
        pos       : #{BOLD}45#{RESET}
        lex_state : #{BOLD}:EXPR_BEG#{RESET}
        token     : #{BOLD}:QUOTED#{RESET} => #{BOLD}"Microsoft.Exchange.Error: foo"#{RESET}
    MSG

    # `parser_state` defaults to `Net::IMAP.debug`:
    Net::IMAP.debug = false
    assert_equal("#{msg} (#{name})", err.detailed_message)
    assert_equal(
      "#{BOLD}#{msg} (#{BOLD_UNDERLINE}#{name}#{RESET}#{BOLD})#{RESET}",
      err.detailed_message(highlight: true)
    )

    # with a nil token
    parser_state = [string, :EXPR_BEG, 45, nil]
    err = Net::IMAP::ResponseParseError.new(msg, string:, parser_state:)
    assert_equal(<<~MSG.strip, err.detailed_message(parser_state: true))
      #{msg} (#{name})
        processed : "tag OK [Error=\\"Microsoft.Exchange.Error: foo\\""
        remaining : "] done\\r\\n"
        pos       : 45
        lex_state : :EXPR_BEG
        token     : nil
    MSG
    assert_equal(<<~MSG.strip, err.detailed_message(highlight: true, parser_state: true))
      #{BOLD}#{msg} (#{BOLD_UNDERLINE}#{name}#{RESET}#{BOLD})#{RESET}
        processed : #{BOLD}"tag OK [Error=\\"Microsoft.Exchange.Error: foo\\""#{RESET}
        remaining : #{BOLD_UNDERLINE}"] done\\r\\n"#{RESET}
        pos       : #{BOLD}45#{RESET}
        lex_state : #{BOLD}:EXPR_BEG#{RESET}
        token     : nil
    MSG

    # with parser_backtrace
    Net::IMAP.debug = false
    parser = Net::IMAP::ResponseParser.new
    error  = parser.parse("* 123 FETCH (UNKNOWN ...)\r\n") rescue $!
    no_hl    = error.detailed_message(parser_backtrace: true)
    no_color = error.detailed_message(parser_backtrace: true, highlight: true)
    assert_include no_hl,    "caller[ 1]: %-30s ("          % "msg_att"
    assert_include no_color, "caller[ 1]: #{BOLD}%-30s#{RESET} (" % "msg_att"
  end

  test "ResponseTooLargeError" do
    err = Net::IMAP::ResponseTooLargeError.new
    assert_nil err.bytes_read
    assert_nil err.literal_size
    assert_nil err.max_response_size

    err = Net::IMAP::ResponseTooLargeError.new("manually set message")
    assert_equal "manually set message", err.message
    assert_nil err.bytes_read
    assert_nil err.literal_size
    assert_nil err.max_response_size

    err = Net::IMAP::ResponseTooLargeError.new(max_response_size: 1024)
    assert_equal "Response size exceeds max_response_size (1024B)", err.message
    assert_nil err.bytes_read
    assert_nil err.literal_size
    assert_equal 1024, err.max_response_size

    err = Net::IMAP::ResponseTooLargeError.new(bytes_read:        1200,
                                               max_response_size: 1200)
    assert_equal 1200, err.bytes_read
    assert_equal "Response size exceeds max_response_size (1200B)", err.message

    err = Net::IMAP::ResponseTooLargeError.new(bytes_read:        800,
                                               literal_size:      1000,
                                               max_response_size: 1200)
    assert_equal  800, err.bytes_read
    assert_equal 1000, err.literal_size
    assert_equal("Response size (800B read + 1000B literal) " \
                 "exceeds max_response_size (1200B)", err.message)
  end

end
