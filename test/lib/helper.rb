require "test/unit"
require "core_assertions"

Test::Unit::TestCase.include Test::Unit::CoreAssertions

class Test::Unit::TestCase
  def wait_for_response_count(imap, type:, count:,
                              timeout: 0.5, interval: 0.001)
    deadline = Time.now + timeout
    loop do
      current_count = imap.responses(type, &:size)
      break :count    if count <= current_count
      break :deadline if deadline < Time.now
      sleep interval
    end
  end
end
