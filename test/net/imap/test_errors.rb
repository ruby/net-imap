# frozen_string_literal: true

require "net/imap"
require "test/unit"

class IMAPErrorsTest < Net::IMAP::TestCase

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
