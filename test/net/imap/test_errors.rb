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
  BOLD_YELLOW    = SGR 1, 33, 40
  CYAN           = SGR 36, 40

  setup do
    @term_env_vars = ENV["TERM"], ENV["NO_COLOR"], ENV["FORCE_COLOR"]
    ENV["TERM"], ENV["NO_COLOR"], ENV["FORCE_COLOR"] = nil, nil, nil
  end

  teardown do
    ENV["TERM"], ENV["NO_COLOR"], ENV["FORCE_COLOR"] = @term_env_vars
  end

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

    expected_no_hl = <<~MSG.strip
      #{msg} (#{name})
        processed : "tag OK [Error=\\"Microsoft.Exchange.Error: foo\\""
        remaining : "] done\\r\\n"
        pos       : 45
        lex_state : :EXPR_BEG
        token     : :QUOTED => "Microsoft.Exchange.Error: foo"
    MSG
    expected_no_color = <<~MSG.strip
      #{BOLD}#{msg} (#{BOLD_UNDERLINE}#{name}#{RESET}#{BOLD})#{RESET}
        processed : #{BOLD}"tag OK [Error=\\"Microsoft.Exchange.Error: foo\\""#{RESET}
        remaining : #{BOLD_UNDERLINE}"] done\\r\\n"#{RESET}
        pos       : #{BOLD}45#{RESET}
        lex_state : #{BOLD}:EXPR_BEG#{RESET}
        token     : #{BOLD}:QUOTED#{RESET} => #{BOLD}"Microsoft.Exchange.Error: foo"#{RESET}
    MSG
    expected_color_hl = <<~MSG.strip
      #{BOLD}#{msg} (#{BOLD_UNDERLINE}#{name}#{RESET}#{BOLD})#{RESET}
        processed : #{CYAN}"tag OK [Error=\\"Microsoft.Exchange.Error: foo\\""#{RESET}
        remaining : #{BOLD_YELLOW}"] done\\r\\n"#{RESET}
        pos       : #{CYAN}45#{RESET}
        lex_state : #{CYAN}:EXPR_BEG#{RESET}
        token     : #{CYAN}:QUOTED#{RESET} => #{CYAN}"Microsoft.Exchange.Error: foo"#{RESET}
    MSG

    ENV["TERM"], ENV["NO_COLOR"], ENV["FORCE_COLOR"] = nil, nil, "0"
    assert_equal(expected_no_hl,    err.detailed_message)
    assert_equal(expected_color_hl, err.detailed_message(highlight: true))
    assert_equal(expected_no_color, err.detailed_message(highlight: true,
                                                         highlight_no_color: true))

    ENV["TERM"], ENV["NO_COLOR"], ENV["FORCE_COLOR"] = "dumb", "1", nil
    assert_equal(expected_no_hl,    err.detailed_message)
    assert_equal(expected_no_color, err.detailed_message(highlight: true))
    assert_equal(expected_color_hl, err.detailed_message(highlight: true,
                                                         highlight_no_color: false))

    ENV["TERM"], ENV["NO_COLOR"], ENV["FORCE_COLOR"] = "xterm", nil, nil
    assert_equal(expected_color_hl, err.detailed_message)
    assert_equal(expected_no_hl,    err.detailed_message(highlight: false))
    assert_equal(expected_no_color, err.detailed_message(highlight_no_color: true))

    ENV["TERM"], ENV["NO_COLOR"], ENV["FORCE_COLOR"] = "dumb", nil, "1"
    assert_equal(expected_color_hl, err.detailed_message)
    assert_equal(expected_no_hl,    err.detailed_message(highlight: false))
    assert_equal(expected_no_color, err.detailed_message(highlight_no_color: true))

    ENV["TERM"], ENV["NO_COLOR"], ENV["FORCE_COLOR"] = "unknown", "1", "1"
    assert_equal(expected_no_color, err.detailed_message)
    assert_equal(expected_no_hl,    err.detailed_message(highlight: false))
    assert_equal(expected_color_hl, err.detailed_message(highlight_no_color: false))

    # reset to nil
    ENV["TERM"], ENV["NO_COLOR"], ENV["FORCE_COLOR"] = nil, nil, nil

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
        processed : #{CYAN}"tag OK [Error=\\"Microsoft.Exchange.Error: foo\\""#{RESET}
        remaining : #{BOLD_YELLOW}"] done\\r\\n"#{RESET}
        pos       : #{CYAN}45#{RESET}
        lex_state : #{CYAN}:EXPR_BEG#{RESET}
        token     : nil
    MSG

    # with parser_backtrace
    Net::IMAP.debug = false
    parser = Net::IMAP::ResponseParser.new
    error  = parser.parse("* 123 FETCH (UNKNOWN ...)\r\n") rescue $!
    no_hl    = error.detailed_message(parser_backtrace: true)
    color_hl = error.detailed_message(parser_backtrace: true, highlight: true)
    no_color = error.detailed_message(parser_backtrace: true, highlight: true,
                                      highlight_no_color: true)
    assert_include no_hl,    "caller[ 1]: %-30s ("          % "msg_att"
    assert_include no_color, "caller[ 1]: #{BOLD}%-30s#{RESET} (" % "msg_att"
    assert_include color_hl, "caller[ 1]: #{CYAN}%-30s#{RESET} (" % "msg_att"
  end

  if defined?(::Ractor)
    %i[ESC_NO_HL ESC_NO_COLOR ESC_COLORS].each do |name|
      test "ResponseParseError::#{name} is Ractor shareable" do
        value = Net::IMAP::ResponseParseError.const_get(name)
        assert Ractor.shareable? value
      end
    end
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
