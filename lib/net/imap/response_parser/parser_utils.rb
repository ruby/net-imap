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

        def lookahead
          @token ||= next_token
        end

        def shift_token
          @token = nil
        end
      end
    end
  end
end
