# frozen_string_literal: true

module Net
  class IMAP < Protocol
    class ResponseParser
      # basic utility methods for parsing.
      #
      # (internal API, subject to change)
      module ParserUtils # :nodoc:

        module Generator

          LOOKAHEAD = "(@token ||= next_token)"
          SHIFT_TOKEN = "(@token = nil)"

          # we can skip lexer for single character matches, as a shortcut
          def def_char_matchers(name, char, token)
            match_name = name.match(/\A[A-Z]/) ? "#{name}!" : name
            char = char.dump
            class_eval <<~RUBY, __FILE__, __LINE__ + 1
              # frozen_string_literal: true

              # like accept(token_symbols); returns token or nil
              def #{name}?
                if @token&.symbol == #{token}
                  #{SHIFT_TOKEN}
                  #{char}
                elsif !@token && @str[@pos] == #{char}
                  @pos += 1
                  #{char}
                end
              end

              # like match(token_symbols); returns token or raises parse_error
              def #{match_name}
                if @token&.symbol == #{token}
                  #{SHIFT_TOKEN}
                  #{char}
                elsif !@token && @str[@pos] == #{char}
                  @pos += 1
                  #{char}
                else
                  parse_error("unexpected %s (expected %p)",
                              @token&.symbol || @str[@pos].inspect, #{char})
                end
              end
            RUBY
          end

        end

        private

        def match(*args)
          token = lookahead
          unless args.include?(token.symbol)
            parse_error('unexpected token %s (expected %s)',
                        token.symbol.id2name,
                        args.collect {|i| i.id2name}.join(" or "))
          end
          shift_token
          token
        end

        # like match, but does not raise error on failure.
        #
        # returns and shifts token on successful match
        # returns nil and leaves @token unshifted on no match
        def accept(*args)
          token = lookahead
          if args.include?(token.symbol)
            shift_token
            token
          end
        end

        # To be used conditionally:
        #   assert_no_lookahead if Net::IMAP.debug
        def assert_no_lookahead
          @token.nil? or
            parse_error("assertion failed: expected @token.nil?, actual %s: %p",
                        @token.symbol, @token.value)
        end

        # like accept, without consuming the token
        def lookahead?(*symbols)
          @token if symbols.include?((@token ||= next_token)&.symbol)
        end

        def lookahead
          @token ||= next_token
        end

        def accept_re(re)
          assert_no_lookahead if Net::IMAP.debug
          re.match(@str, @pos) and @pos = $~.end(0)
          $~
        end

        def match_re(re, name)
          assert_no_lookahead if Net::IMAP.debug
          if re.match(@str, @pos)
            @pos = $~.end(0)
            $~
          else
            parse_error("invalid #{name}")
          end
        end

        def shift_token
          @token = nil
        end

        def parse_error(fmt, *args)
          msg = format(fmt, *args)
          if IMAP.debug
            local_path = File.dirname(__dir__)
            tok = @token ? "%s: %p" % [@token.symbol, @token.value] : "nil"
            warn "%s %s: %s"        % [self.class, __method__, msg]
            warn "  tokenized : %s" % [@str[...@pos].dump]
            warn "  remaining : %s" % [@str[@pos..].dump]
            warn "  @lex_state: %s" % [@lex_state]
            warn "  @pos      : %d" % [@pos]
            warn "  @token    : %s" % [tok]
            caller_locations(1..20).each_with_index do |cloc, idx|
              next unless cloc.path&.start_with?(local_path)
              warn "  caller[%2d]: %-30s (%s:%d)" % [
                idx,
                cloc.base_label,
                File.basename(cloc.path, ".rb"),
                cloc.lineno
              ]
            end
          end
          raise ResponseParseError, msg
        end

      end
    end
  end
end
