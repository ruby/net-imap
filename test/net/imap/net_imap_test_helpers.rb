# frozen_string_literal: true

require "net/imap"
require "test/unit"
require "yaml"

# Compatibility with older versions, e.g. the version comes with ruby 2.7
module YAMLPolyfill
  unless YAML.respond_to? :unsafe_load_file
    refine YAML.singleton_class do
      def unsafe_load_file(...) load_file(...) end
    end
  end
end
using YAMLPolyfill

module NetIMAPTestHelpers
  module TestFixtureGenerators

    attr_reader :fixtures

    def load_fixture_data(*test_fixture_path)
      dir = self::TEST_FIXTURE_PATH
      YAML.unsafe_load_file File.join(dir, *test_fixture_path)
    end

    def generate_tests_from(fixture_data: nil, fixture_file: nil)
      fixture_data ||= load_fixture_data fixture_file
      tests = fixture_data.fetch(:tests)

      tests.each do |name, test|
        type = test.fetch(:test_type) {
          test.key?(:expected) ? :parser_assert_equal : :parser_pending
        }
        name = "test_#{name}" unless name.start_with? "test_"
        name = name.to_sym
        raise "#{name} is already defined" if instance_methods.include?(name)
        # warn "define_method :#{name} = #{type}..."

        case type

        when :parser_assert_equal
          response = test.fetch(:response)
          expected = test.fetch(:expected)

          define_method name do
            with_debug do
              parser = Net::IMAP::ResponseParser.new
              actual = parser.parse response
              assert_equal expected, actual
            end
          end

        when :parser_pending
          response = test.fetch(:response)

          define_method name do
            with_debug do
              parser = Net::IMAP::ResponseParser.new
              actual = parser.parse response
              puts YAML.dump name => {response: response, expected: actual}
              pend "update tests with expected data..."
            end
          end

        when :assert_parse_failure
          response = test.fetch(:response)
          message  = test.fetch(:message)

          define_method name do
            err = assert_raise(Net::IMAP::ResponseParseError) do
              Net::IMAP::ResponseParser.new.parse response
            end
            assert_match(message, err.message)
          end

        end
      end

    end
  end

  def with_debug(bool = true)
    Net::IMAP.debug, original = bool, Net::IMAP.debug
    yield
  ensure
    Net::IMAP.debug = original
  end

end
