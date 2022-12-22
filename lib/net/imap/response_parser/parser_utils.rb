# frozen_string_literal: true

module Net
  class IMAP < Protocol
    class ResponseParser
      # basic utility methods for parsing.
      #
      # (internal API, subject to change)
      module ParserUtils # :nodoc:

        private

        def match(*args, lex_state: @lex_state)
          if @token && lex_state != @lex_state
            parse_error("invalid lex_state change to %s with unconsumed token",
                        lex_state)
          end
          begin
            @lex_state, original_lex_state = lex_state, @lex_state
            token = lookahead
            unless args.include?(token.symbol)
              parse_error('unexpected token %s (expected %s)',
                          token.symbol.id2name,
                          args.collect {|i| i.id2name}.join(" or "))
            end
            shift_token
            return token
          ensure
            @lex_state = original_lex_state
          end
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

        # like accept, without consuming the token
        def lookahead?(*symbols)
          @token if symbols.include?((@token ||= next_token)&.symbol)
        end

        def lookahead
          @token ||= next_token
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
