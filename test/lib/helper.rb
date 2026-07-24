if !(ENV["SIMPLECOV_DISABLE"] in /\A(1|y(es)?|t(rue)?)\z/i) &&
    RUBY_ENGINE == "ruby" # C Ruby only

  require "simplecov"

  SimpleCov.start do
    command_name "Net::IMAP tests"
  end
end

require "test/unit"
require "core_assertions"

Test::Unit::TestCase.include Test::Unit::CoreAssertions

require "net/imap"
class Net::IMAP::TestCase < Test::Unit::TestCase
  SOCKET_SUPPORT_HAPPY_EYEBALLS = begin
    Socket.tcp_fast_fallback
    true
  rescue NoMethodError
    false
  end

  def setup
    Net::IMAP.config.reset
    @do_not_reverse_lookup = Socket.do_not_reverse_lookup
    Socket.do_not_reverse_lookup = true
    if SOCKET_SUPPORT_HAPPY_EYEBALLS
      @tcp_fast_fallback = Socket.tcp_fast_fallback
      Socket.tcp_fast_fallback = false
    end
    @threads = []
  end

  def teardown
    assert_join_threads(@threads) unless @threads.empty?
  ensure
    Socket.do_not_reverse_lookup = @do_not_reverse_lookup
    if SOCKET_SUPPORT_HAPPY_EYEBALLS
      Socket.tcp_fast_fallback = @tcp_fast_fallback
    end
  end

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

  def wait_for_receiver_thread_terminating(imap, timeout: 0.5, interval: 0.001)
    deadline = Time.now + timeout
    loop do
      break if imap.instance_exec {
        synchronize { @receiver_thread_terminating }
      }
      break :deadline if deadline < Time.now
      sleep interval
    end
  end

  # assert_linear_performance didn't fail reliably until "n" was far too high,
  # even though the problem was very obvious at lower "n" values, by looking at
  # the mean (plus stddev) rather than the max (plus variance-based "safety
  # factor").
  #
  # So rather than use "max" as the baseline, this uses μ + 2σ (or max).
  def assert_strict_linear_time(sequence, prepare: proc do end,
                                base_repeats: 100,
                                repeats:        5,
                                allow_stdev_above_mean: 2,
                                outlier_safety_factor:  3,
                                mean_safety_factor:     2,
                                verbose: false,
                                &code)
    pend "No PERFORMANCE_CLOCK found" unless defined?(PERFORMANCE_CLOCK)

    measure  = proc do |&block|
      st = Process.clock_gettime(PERFORMANCE_CLOCK)
      block.call
      t = Process.clock_gettime(PERFORMANCE_CLOCK)
      t - st
    end

    measure_base = proc do |sequence, prepare:, &code|
      stats = RunningStats.new
      base_repeats.times do
        *args = prepare.(sequence.first)
        time = measure.call { code.call(*args) }
        warn "  - %0.9f" % [time] if verbose == :very
        stats.push time
      end
      stats
    end

    scale = ->(base, base_size, size) { base * size.fdiv(base_size) }

    warn "Measuring (#{base_repeats} times) for n=#{sequence.first}." if verbose
    base_stats = measure_base.(sequence, prepare:, &code)
    base_time  = [base_stats.stddev_above_mean(3), base_stats.max].min

    base_timeout_msg = "min=%s max=%s mean=%s stddev=%s timeout=%s" % [
      base_stats.min, base_stats.max, base_stats.mean, base_stats.stddev,
      base_time
    ].map { "%0.6f" % _1 }

    warn "  n=%d -> %p" % [sequence.first, base_stats] if verbose
    warn "  base timeout=%0.6f" % [base_time] if verbose

    sequence.each.drop(1).to_h {|n|
      linear_limit = scale.(base_time, sequence.first, n)
      each_timeout = linear_limit * outlier_safety_factor
      mean_timeout = linear_limit *    mean_safety_factor
      full_timeout = mean_timeout * repeats * 1.1
      timeout_msg = "for n=%s linear_limit=%0.6f timeout=%0.6f mean_timeout=%0.6f" % [
        n, linear_limit, each_timeout, mean_timeout
      ]
      warn "Measuring (#{repeats} times) #{timeout_msg}:" if verbose
      timeout_msg = "#{timeout_msg} #{base_timeout_msg}"
      *args = prepare.call(n)
      times = Timeout.timeout(full_timeout, Timeout::Error, timeout_msg) do
        Array.new(repeats) {
          time = Timeout.timeout(each_timeout, Timeout::Error, timeout_msg) do
            measure.call do code.call(*args) end
          end
          assert_operator time, :<=, each_timeout,
            "super-linear time %0.6f %s" % [time, timeout_msg]
          warn "  ---- %0.9f" % [time] if verbose == :very
          time
        }
      end
      stats = RunningStats.new(times)
      warn "  n=%d -> %p" % [n, stats] if verbose
      assert_operator stats.mean, :<=, mean_timeout,
        "super-linear mean time %0.6f %s" % [stats.mean, timeout_msg]
      [n, stats]
    }
  end

  class RunningStats
    attr_reader :samples, :min, :max, :mean

    def initialize(input = nil)
      @samples = 0
      @mean    = 0.0
      @s       = 0.0
      @min     = nil
      @max     = nil
      input&.each do push _1 end
    end

    def push(x)
      @min      = @min ? [@min, x].min : x
      @max      = @max ? [@max, x].max : x
      @samples += 1
      delta     = (x - @mean)
      @mean    += delta / @samples
      @s       += delta * (x - @mean)
    end

    def variance; (@samples >= 1) ? @s / (@samples - 1) : 0.0 end
    def stddev;   Math.sqrt(variance) end

    def stddev_above_mean(mult = 1) = mean + mult * stddev

    def inspect
      "#<%s samples=%d min=%0.6f max=%0.6f mean=%0.6f stddev=%0.6f>" % [
        self.class, samples, min, max, mean, stddev
      ]
    end
  end

  # Copied from minitest
  def assert_pattern
    flunk "assert_pattern requires a block to capture errors." unless block_given?
    assert_block do
      yield
      true
    rescue NoMatchingPatternError => e
      flunk e.message
    end
  end

  def assert_stream_closed_error
    assert_local_raise(IOError, /\A(?:stream closed|closed stream)\z/) do
      yield
    end
  end

  # Combines +assert_raise+ and +assert_raise_with_message+ with an assertion
  # that the backtrace matches the caller.
  def assert_local_raise(expected, message = nil)
    error = nil
    block = -> do
      yield
    rescue expected => error
      raise
    end
    if message
      assert_raise_with_message(expected, message, &block)
    else
      assert_raise(expected, &block)
    end
    stack = caller
    pend_if_jruby("stack traces don't match in JRuby 10.0.1.0") do
      assert_equal stack, error.backtrace&.last(stack.size)
    end
    error
  end

  # Combines +assert_local_raise+ with an assertion that the exception's cause
  # is in the receiver thread.
  #
  # Must be called at least once while the receiver_thread is still running, so
  # it can capture the top of the stacktrace.  After that, it'll continue to use
  # the same stacktrace.
  def assert_reraised(*args, imap: nil, &block)
    @rcvr_thread_trace ||= imap.instance_variable_get(:@receiver_thread)
      &.backtrace&.last(2)
    error = assert_local_raise(*args, &block)
    refute_nil @rcvr_thread_trace, "receiver thread not running?"
    size = @rcvr_thread_trace.size
    assert_equal @rcvr_thread_trace, error.cause&.backtrace.last(size)
  end

  def pend_if(condition, *args, &block)
    if condition
      pend(*args, &block)
    else
      block.call if block
    end
  end

  def pend_unless(condition, *args, &block)
    if condition
      block.call if block
    else
      pend(*args, &block)
    end
  end

  def omit_unless_cruby(msg = "test omitted for non-CRuby", &block)
    omit_unless(RUBY_ENGINE == "ruby", msg, &block)
  end

  def omit_if_truffleruby(msg = "test omitted on TruffleRuby", &block)
    omit_if(RUBY_ENGINE == "truffleruby", msg, &block)
  end

  def omit_if_jruby(msg = "test omitted on JRuby", &block)
    omit_if(RUBY_ENGINE == "jruby", msg, &block)
  end

  def pend_unless_cruby(msg = "test is pending for non-CRuby", &block)
    pend_unless(RUBY_ENGINE == "ruby", msg, &block)
  end

  def pend_if_truffleruby(msg = "test is pending on TruffleRuby", &block)
    pend_if(RUBY_ENGINE == "truffleruby", msg, &block)
  end

  def pend_if_jruby(msg = "test is pending on JRuby", &block)
    pend_if(RUBY_ENGINE == "jruby", msg, &block)
  end

end

require_relative "profiling_helper"
