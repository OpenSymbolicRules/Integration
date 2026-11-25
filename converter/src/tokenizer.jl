@enum TokenKind begin
    TOK_SYMBOL       # identifier: x, Sin, FreeQ, etc.
    TOK_INTEGER      # integer literal: 1, -3, 100
    TOK_REAL         # floating point: 2.5, 3.14
    TOK_STRING       # "..."
    TOK_LBRACKET     # [
    TOK_RBRACKET     # ]
    TOK_LBRACE       # {
    TOK_RBRACE       # }
    TOK_LPAREN       # (
    TOK_RPAREN       # )
    TOK_COMMA        # ,
    TOK_PLUS         # +
    TOK_MINUS        # -
    TOK_STAR         # *
    TOK_RUBI_STAR    # \[Star], RUBI's Star operator (not plain Times)
    TOK_SLASH        # /
    TOK_CARET        # ^
    TOK_BLANK        # _  (pattern blank)
    TOK_BLANKSEQ     # __ (blank sequence)
    TOK_BLANKNULLSEQ # ___ (blank null sequence)
    TOK_DOT          # .  (standalone dot, e.g., in a_.)
    TOK_SETDELAYED   # :=
    TOK_SET          # = (local binding inside With)
    TOK_CONDITION    # /;
    TOK_AND          # &&
    TOK_OR           # ||
    TOK_NOT          # !
    TOK_EQUAL        # ==
    TOK_UNSAMEQ      # =!= (structural inequality)
    TOK_NOTEQUAL     # !=
    TOK_LESSEQUAL    # <=
    TOK_GREATEREQUAL # >=
    TOK_LESS         # <
    TOK_GREATER      # >
    TOK_RULE         # ->
    TOK_RULEDELAYED  # :>
    TOK_SEMICOLON    # ;
    TOK_LPART        # [[ (Part)
    TOK_RPART        # ]]
    TOK_HASH         # # (Slot)
    TOK_HASHHASH     # ## (SlotSequence)
    TOK_AMP          # & (Function)
    TOK_AT           # @ (Prefix application)
    TOK_ATAT         # @@ (Apply)
    TOK_PIPE         # | (Alternatives in patterns)
    TOK_PRIME        # ' (postfix derivative notation)
    TOK_NEWLINE      # \n (used for line tracking only)
    TOK_EOF          # end of input
end

struct Token
    kind::TokenKind
    value::String
    line::Int
    col::Int
end

struct TokenizerError <: Exception
    message::String
    line::Int
    col::Int
end

mutable struct Tokenizer
    source::String
    pos::Int
    line::Int
    col::Int
    tokens::Vector{Token}
end

Tokenizer(source::AbstractString) = Tokenizer(String(source), 1, 1, 1, Token[])

function peek_char(t::Tokenizer)::Union{Char, Nothing}
    t.pos <= ncodeunits(t.source) ? t.source[t.pos] : nothing
end

function next_char!(t::Tokenizer)::Union{Char, Nothing}
    t.pos > ncodeunits(t.source) && return nothing
    c = t.source[t.pos]
    t.pos += ncodeunits(c)
    if c == '\n'
        t.line += 1
        t.col = 1
    else
        t.col += 1
    end
    c
end

function peek_ahead(t::Tokenizer, offset::Int=1)::Union{Char, Nothing}
    p = t.pos
    for _ in 1:offset
        p > ncodeunits(t.source) && return nothing
        p = nextind(t.source, p)
    end
    p > ncodeunits(t.source) ? nothing : t.source[p]
end

function skip_whitespace!(t::Tokenizer)
    while true
        c = peek_char(t)
        c === nothing && return
        if c == ' ' || c == '\t' || c == '\r' || c == '\n'
            next_char!(t)
        else
            return
        end
    end
end

function skip_comment!(t::Tokenizer)::Bool
    c = peek_char(t)
    c === nothing && return false
    if c == '(' && peek_ahead(t) == '*'
        next_char!(t)  # skip (
        next_char!(t)  # skip *
        depth = 1
        while depth > 0
            c = next_char!(t)
            c === nothing && throw(TokenizerError("Unterminated comment", t.line, t.col))
            if c == '(' && peek_char(t) == '*'
                next_char!(t)
                depth += 1
            elseif c == '*' && peek_char(t) == ')'
                next_char!(t)
                depth -= 1
            end
        end
        return true
    end
    false
end

function read_symbol!(t::Tokenizer)::Token
    start_line, start_col = t.line, t.col
    buf = IOBuffer()
    while true
        c = peek_char(t)
        c === nothing && break
        if isletter(c) || isdigit(c) || c == '$' || c == '`'
            write(buf, next_char!(t))
        else
            break
        end
    end
    Token(TOK_SYMBOL, String(take!(buf)), start_line, start_col)
end

function read_number!(t::Tokenizer)::Token
    start_line, start_col = t.line, t.col
    buf = IOBuffer()
    has_dot = false
    while true
        c = peek_char(t)
        c === nothing && break
        if isdigit(c)
            write(buf, next_char!(t))
        elseif c == '.' && !has_dot
            # Check it's a decimal dot, not a pattern dot (e.g., 1.)
            # In Mathematica, 1. is a real number, but a_. is pattern with dot
            next = peek_ahead(t)
            if next !== nothing && isdigit(next)
                has_dot = true
                write(buf, next_char!(t))
            elseif next === nothing || (!isletter(next) && next != '_')
                # standalone "1." — treat as real
                has_dot = true
                write(buf, next_char!(t))
            else
                break
            end
        else
            break
        end
    end
    kind = has_dot ? TOK_REAL : TOK_INTEGER
    Token(kind, String(take!(buf)), start_line, start_col)
end

function read_string!(t::Tokenizer)::Token
    start_line, start_col = t.line, t.col
    next_char!(t)  # skip opening "
    buf = IOBuffer()
    while true
        c = next_char!(t)
        c === nothing && throw(TokenizerError("Unterminated string", start_line, start_col))
        if c == '"'
            break
        elseif c == '\\'
            nc = next_char!(t)
            nc === nothing && throw(TokenizerError("Unterminated escape in string", t.line, t.col))
            write(buf, nc)
        else
            write(buf, c)
        end
    end
    Token(TOK_STRING, String(take!(buf)), start_line, start_col)
end

function tokenize!(t::Tokenizer)::Vector{Token}
    while true
        skip_whitespace!(t)

        # Skip comments
        while skip_comment!(t)
            skip_whitespace!(t)
        end

        c = peek_char(t)
        c === nothing && break

        line, col = t.line, t.col

        # RUBI's notebook-generated source uses a named Wolfram character.
        # Preserve its distinct Star head; it has rewrite behavior of its own.
        if startswith(SubString(t.source, t.pos), raw"\[Star]")
            for _ in 1:length(raw"\[Star]")
                next_char!(t)
            end
            push!(t.tokens, Token(TOK_RUBI_STAR, raw"\[Star]", line, col))
            continue
        end

        # Numbers
        if isdigit(c)
            push!(t.tokens, read_number!(t))
            continue
        end

        # Symbols (identifiers)
        if isletter(c) || c == '$'
            push!(t.tokens, read_symbol!(t))
            continue
        end

        # Strings
        if c == '"'
            push!(t.tokens, read_string!(t))
            continue
        end

        # Two-character operators (check first)
        next = peek_ahead(t)

        if c == ':' && next == '='
            next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_SETDELAYED, ":=", line, col))
            continue
        end
        if c == ':' && next == '>'
            next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_RULEDELAYED, ":>", line, col))
            continue
        end
        if c == '/' && next == ';'
            next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_CONDITION, "/;", line, col))
            continue
        end
        if c == '&' && next == '&'
            next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_AND, "&&", line, col))
            continue
        end
        if c == '|' && next == '|'
            next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_OR, "||", line, col))
            continue
        end
        if c == '=' && next == '!' && peek_ahead(t, 2) == '='
            next_char!(t); next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_UNSAMEQ, "=!=", line, col))
            continue
        end
        if c == '=' && next == '='
            next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_EQUAL, "==", line, col))
            continue
        end
        if c == '!' && next == '='
            next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_NOTEQUAL, "!=", line, col))
            continue
        end
        if c == '<' && next == '='
            next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_LESSEQUAL, "<=", line, col))
            continue
        end
        if c == '>' && next == '='
            next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_GREATEREQUAL, ">=", line, col))
            continue
        end
        if c == '-' && next == '>'
            next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_RULE, "->", line, col))
            continue
        end
        if c == '@' && next == '@'
            next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_ATAT, "@@", line, col))
            continue
        end
        if c == '#' && next == '#'
            next_char!(t); next_char!(t)
            push!(t.tokens, Token(TOK_HASHHASH, "##", line, col))
            continue
        end

        # Underscores: ___, __, _
        if c == '_'
            next_char!(t)
            if peek_char(t) == '_'
                next_char!(t)
                if peek_char(t) == '_'
                    next_char!(t)
                    push!(t.tokens, Token(TOK_BLANKNULLSEQ, "___", line, col))
                else
                    push!(t.tokens, Token(TOK_BLANKSEQ, "__", line, col))
                end
            else
                push!(t.tokens, Token(TOK_BLANK, "_", line, col))
            end
            continue
        end

        # Part brackets [[ and ]] are handled by emitting two separate tokens
        # The parser resolves whether [[ means Part or nested function calls
        # by tracking bracket depth.

        # Single-character tokens
        next_char!(t)
        tok = if c == '['
            Token(TOK_LBRACKET, "[", line, col)
        elseif c == ']'
            Token(TOK_RBRACKET, "]", line, col)
        elseif c == '{'
            Token(TOK_LBRACE, "{", line, col)
        elseif c == '}'
            Token(TOK_RBRACE, "}", line, col)
        elseif c == '('
            Token(TOK_LPAREN, "(", line, col)
        elseif c == ')'
            Token(TOK_RPAREN, ")", line, col)
        elseif c == ','
            Token(TOK_COMMA, ",", line, col)
        elseif c == '+'
            Token(TOK_PLUS, "+", line, col)
        elseif c == '-'
            Token(TOK_MINUS, "-", line, col)
        elseif c == '*'
            Token(TOK_STAR, "*", line, col)
        elseif c == '/'
            Token(TOK_SLASH, "/", line, col)
        elseif c == '^'
            Token(TOK_CARET, "^", line, col)
        elseif c == '.'
            Token(TOK_DOT, ".", line, col)
        elseif c == ';'
            Token(TOK_SEMICOLON, ";", line, col)
        elseif c == '='
            Token(TOK_SET, "=", line, col)
        elseif c == '!'
            Token(TOK_NOT, "!", line, col)
        elseif c == '<'
            Token(TOK_LESS, "<", line, col)
        elseif c == '>'
            Token(TOK_GREATER, ">", line, col)
        elseif c == '#'
            Token(TOK_HASH, "#", line, col)
        elseif c == '&'
            Token(TOK_AMP, "&", line, col)
        elseif c == '@'
            Token(TOK_AT, "@", line, col)
        elseif c == '|'
            Token(TOK_PIPE, "|", line, col)
        elseif c == '\''
            Token(TOK_PRIME, "'", line, col)
        else
            throw(TokenizerError("Unexpected character: '$c'", line, col))
        end
        push!(t.tokens, tok)
    end

    push!(t.tokens, Token(TOK_EOF, "", t.line, t.col))
    t.tokens
end

function tokenize(source::AbstractString)::Vector{Token}
    t = Tokenizer(source)
    tokenize!(t)
end
