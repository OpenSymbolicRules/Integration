# Recursive descent parser for the RUBI subset of Wolfram Language
# Produces an AST of MathematicaExpr nodes

# AST node types
abstract type MExpr end

struct MSymbol <: MExpr
    name::String
end

struct MInteger <: MExpr
    value::Integer  # Int or BigInt for very large constants
end

struct MReal <: MExpr
    value::Float64
end

struct MString <: MExpr
    value::String
end

struct MPattern <: MExpr
    name::String
    blank_type::Symbol    # :blank, :optional, :blankseq, :blanknullseq
    type_head::Union{String,Nothing}
end

struct MFunction <: MExpr
    head::String
    args::Vector{Any}  # Vector of MExpr
end

struct ParserError <: Exception
    message::String
    line::Int
    col::Int
end

mutable struct Parser
    tokens::Vector{Token}
    pos::Int
end

Parser(tokens::Vector{Token}) = Parser(tokens, 1)

function current(p::Parser)::Token
    p.tokens[p.pos]
end

function peek(p::Parser)::TokenKind
    current(p).kind
end

function peek_ahead_kind(p::Parser, offset::Int=1)::TokenKind
    idx = p.pos + offset
    idx <= length(p.tokens) ? p.tokens[idx].kind : TOK_EOF
end

function advance!(p::Parser)::Token
    tok = p.tokens[p.pos]
    if p.pos < length(p.tokens)
        p.pos += 1
    end
    tok
end

function expect!(p::Parser, kind::TokenKind)::Token
    tok = current(p)
    if tok.kind != kind
        throw(ParserError("Expected $kind, got $(tok.kind) ('$(tok.value)')", tok.line, tok.col))
    end
    advance!(p)
end

function at(p::Parser, kind::TokenKind)::Bool
    peek(p) == kind
end

# ─── Entry point ───

function parse_expr(p::Parser)::MExpr
    parse_set_delayed(p)
end

# ─── Precedence levels (lowest to highest) ───

# SetDelayed: lhs := rhs
function parse_set_delayed(p::Parser)::MExpr
    left = parse_condition(p)
    if at(p, TOK_SETDELAYED)
        advance!(p)
        right = parse_condition(p)
        return MFunction("SetDelayed", [left, right])
    elseif at(p, TOK_SET)
        advance!(p)
        right = parse_condition(p)
        return MFunction("Set", [left, right])
    end
    left
end

# Condition: expr /; test
function parse_condition(p::Parser)::MExpr
    left = parse_or(p)
    if at(p, TOK_CONDITION)
        advance!(p)
        right = parse_or(p)
        return MFunction("Condition", [left, right])
    end
    left
end

# Or: a || b
function parse_or(p::Parser)::MExpr
    left = parse_and(p)
    while at(p, TOK_OR)
        advance!(p)
        right = parse_and(p)
        left = MFunction("Or", [left, right])
    end
    left
end

# And: a && b
function parse_and(p::Parser)::MExpr
    left = parse_not(p)
    while at(p, TOK_AND)
        advance!(p)
        right = parse_not(p)
        left = MFunction("And", [left, right])
    end
    left
end

# Not: !a (prefix)
function parse_not(p::Parser)::MExpr
    if at(p, TOK_NOT)
        advance!(p)
        arg = parse_not(p)
        return MFunction("Not", [arg])
    end
    parse_comparison(p)
end

# Comparison: a == b, a != b, a < b, a > b, a <= b, a >= b
function parse_comparison(p::Parser)::MExpr
    left = parse_alternatives(p)
    if at(p, TOK_EQUAL)
        advance!(p)
        right = parse_alternatives(p)
        return MFunction("Equal", [left, right])
    elseif at(p, TOK_NOTEQUAL)
        advance!(p)
        right = parse_alternatives(p)
        return MFunction("Unequal", [left, right])
    elseif at(p, TOK_LESS)
        advance!(p)
        right = parse_alternatives(p)
        return MFunction("Less", [left, right])
    elseif at(p, TOK_GREATER)
        advance!(p)
        right = parse_alternatives(p)
        return MFunction("Greater", [left, right])
    elseif at(p, TOK_LESSEQUAL)
        advance!(p)
        right = parse_alternatives(p)
        return MFunction("LessEqual", [left, right])
    elseif at(p, TOK_GREATEREQUAL)
        advance!(p)
        right = parse_alternatives(p)
        return MFunction("GreaterEqual", [left, right])
    end
    left
end

# Alternatives: a | b (in patterns)
function parse_alternatives(p::Parser)::MExpr
    left = parse_rule(p)
    if at(p, TOK_PIPE)
        args = MExpr[left]
        while at(p, TOK_PIPE)
            advance!(p)
            push!(args, parse_rule(p))
        end
        return MFunction("Alternatives", args)
    end
    left
end

# Rule: a -> b, a :> b
function parse_rule(p::Parser)::MExpr
    left = parse_addition(p)
    if at(p, TOK_RULE)
        advance!(p)
        right = parse_addition(p)
        return MFunction("Rule", [left, right])
    elseif at(p, TOK_RULEDELAYED)
        advance!(p)
        right = parse_addition(p)
        return MFunction("RuleDelayed", [left, right])
    end
    left
end

# Addition: a + b, a - b (left-associative, collects into Plus)
function parse_addition(p::Parser)::MExpr
    left = parse_multiplication(p)
    args = nothing
    while at(p, TOK_PLUS) || at(p, TOK_MINUS)
        if args === nothing
            args = MExpr[left]
        end
        if at(p, TOK_PLUS)
            advance!(p)
            push!(args, parse_multiplication(p))
        else  # TOK_MINUS
            advance!(p)
            term = parse_multiplication(p)
            push!(args, MFunction("Times", [MInteger(-1), term]))
        end
    end
    args === nothing ? left : MFunction("Plus", args)
end

# Multiplication: a * b, a / b, implicit multiplication
function parse_multiplication(p::Parser)::MExpr
    left = parse_unary(p)
    args = nothing
    while true
        if at(p, TOK_RUBI_STAR)
            advance!(p)
            lhs = args === nothing ? left : MFunction("Times", args)
            left = MFunction("Star", [lhs, parse_unary(p)])
            args = nothing
        elseif at(p, TOK_STAR)
            if args === nothing; args = MExpr[left]; end
            advance!(p)
            push!(args, parse_unary(p))
        elseif at(p, TOK_SLASH)
            if args === nothing; args = MExpr[left]; end
            advance!(p)
            denom = parse_unary(p)
            push!(args, MFunction("Power", [denom, MInteger(-1)]))
        elseif can_start_implicit_multiply(p)
            # Implicit multiplication: 2x, a b, x f[y]
            if args === nothing; args = MExpr[left]; end
            push!(args, parse_unary(p))
        else
            break
        end
    end
    args === nothing ? left : MFunction("Times", args)
end

function can_start_implicit_multiply(p::Parser)::Bool
    k = peek(p)
    # An implicit multiply happens when the next token can start an atom
    # but is NOT an operator, delimiter, or EOF
    (k == TOK_SYMBOL || k == TOK_INTEGER || k == TOK_REAL ||
     k == TOK_LPAREN || k == TOK_HASH) &&
    # But not after function application brackets
    true
end

# Unary minus: -a
function parse_unary(p::Parser)::MExpr
    if at(p, TOK_MINUS)
        advance!(p)
        arg = parse_unary(p)
        if arg isa MInteger
            return MInteger(-arg.value)
        elseif arg isa MReal
            return MReal(-arg.value)
        else
            return MFunction("Times", [MInteger(-1), arg])
        end
    elseif at(p, TOK_PLUS)
        advance!(p)
        return parse_unary(p)
    end
    parse_power(p)
end

# Power: a^b (right-associative)
function parse_power(p::Parser)::MExpr
    base = parse_postfix(p)
    if at(p, TOK_CARET)
        advance!(p)
        exp = parse_unary(p)  # right-associative: recurse into unary
        return MFunction("Power", [base, exp])
    end
    base
end

# Postfix: function application f[x], Part f[[i]], pattern x_, x_., x_Type
function parse_postfix(p::Parser)::MExpr
    atom = parse_atom(p)
    while true
        if at(p, TOK_LBRACKET)
            advance!(p)
            if at(p, TOK_LBRACKET)
                # Part: expr[[index]] — two consecutive [
                advance!(p)
                args = parse_arglist(p, TOK_RBRACKET)
                expect!(p, TOK_RBRACKET)
                expect!(p, TOK_RBRACKET)
                atom = MFunction("Part", vcat([atom], args))
            else
                # Function application: f[args]
                args = parse_arglist(p, TOK_RBRACKET)
                expect!(p, TOK_RBRACKET)
                head_name = expr_to_head(atom)
                atom = MFunction(head_name, args)
            end
        elseif at(p, TOK_BLANK) || at(p, TOK_BLANKSEQ) || at(p, TOK_BLANKNULLSEQ)
            # Pattern: x_, x__, x___
            atom = parse_pattern_postfix(atom, p)
        elseif at(p, TOK_AMP)
            # Pure function: expr&
            advance!(p)
            atom = MFunction("Function", [atom])
        elseif at(p, TOK_AT)
            # Prefix application: f @ x  means f[x]
            advance!(p)
            arg = parse_power(p)
            head_name = expr_to_head(atom)
            atom = MFunction(head_name, [arg])
        elseif at(p, TOK_ATAT)
            # Apply: f @@ expr  means Apply[f, expr]
            advance!(p)
            arg = parse_power(p)
            atom = MFunction("Apply", [atom, arg])
        else
            break
        end
    end
    atom
end

function parse_pattern_postfix(name_expr::MExpr, p::Parser)::MExpr
    name = expr_to_symbol_name(name_expr)

    if at(p, TOK_BLANK)
        advance!(p)
        # Check for type head: x_Integer
        type_head = nothing
        if at(p, TOK_SYMBOL)
            type_head = current(p).value
            advance!(p)
        end
        # Check for optional dot: x_.
        if at(p, TOK_DOT)
            advance!(p)
            return MPattern(name, :optional, type_head)
        end
        return MPattern(name, :blank, type_head)
    elseif at(p, TOK_BLANKSEQ)
        advance!(p)
        return MPattern(name, :blankseq, nothing)
    elseif at(p, TOK_BLANKNULLSEQ)
        advance!(p)
        return MPattern(name, :blanknullseq, nothing)
    end

    name_expr
end

function expr_to_head(expr::MExpr)::String
    if expr isa MSymbol
        return expr.name
    elseif expr isa MPattern
        return map_wildcard(expr.name, expr.blank_type, expr.type_head)
    end
    # For compound expressions used as heads, return a string representation
    "UnknownHead"
end

function expr_to_symbol_name(expr::MExpr)::String
    if expr isa MSymbol
        return expr.name
    elseif expr isa MInteger
        return string(expr.value)
    end
    ""
end

# Atom: number, symbol, string, list, parenthesized expression, slot
function parse_atom(p::Parser)::MExpr
    tok = current(p)

    if tok.kind == TOK_INTEGER
        advance!(p)
        big = parse(BigInt, tok.value)
        val = typemin(Int) <= big <= typemax(Int) ? Int(big) : big
        return MInteger(val)
    end

    if tok.kind == TOK_REAL
        advance!(p)
        return MReal(parse(Float64, tok.value))
    end

    if tok.kind == TOK_SYMBOL
        advance!(p)
        return MSymbol(tok.value)
    end

    if tok.kind == TOK_STRING
        advance!(p)
        return MString(tok.value)
    end

    if tok.kind == TOK_LPAREN
        advance!(p)
        expr = parse_expr(p)
        expect!(p, TOK_RPAREN)
        return expr
    end

    if tok.kind == TOK_LBRACE
        advance!(p)
        args = parse_arglist(p, TOK_RBRACE)
        expect!(p, TOK_RBRACE)
        return MFunction("List", args)
    end

    if tok.kind == TOK_HASH
        advance!(p)
        # Slot: # or #n
        if at(p, TOK_INTEGER)
            n = current(p).value
            advance!(p)
            return MFunction("Slot", [MInteger(parse(Int, n))])
        end
        return MFunction("Slot", [MInteger(1)])
    end

    if tok.kind == TOK_HASHHASH
        advance!(p)
        return MFunction("SlotSequence", [MInteger(1)])
    end

    # Standalone blank (unnamed pattern): _, __, ___
    if tok.kind == TOK_BLANK
        advance!(p)
        type_head = nothing
        if at(p, TOK_SYMBOL)
            type_head = current(p).value
            advance!(p)
        end
        if at(p, TOK_DOT)
            advance!(p)
            return MPattern("", :optional, type_head)
        end
        return MPattern("", :blank, type_head)
    end
    if tok.kind == TOK_BLANKSEQ
        advance!(p)
        return MPattern("", :blankseq, nothing)
    end
    if tok.kind == TOK_BLANKNULLSEQ
        advance!(p)
        return MPattern("", :blanknullseq, nothing)
    end

    throw(ParserError("Unexpected token: $(tok.kind) ('$(tok.value)')", tok.line, tok.col))
end

function parse_arglist(p::Parser, closing::TokenKind)::Vector{Any}
    args = MExpr[]
    if at(p, closing)
        return args
    end
    push!(args, parse_expr(p))
    while at(p, TOK_COMMA)
        advance!(p)
        push!(args, parse_expr(p))
    end
    args
end

# ─── Semicolon-separated compound expressions ───

function parse_compound(p::Parser)::MExpr
    expr = parse_expr(p)
    if at(p, TOK_SEMICOLON)
        args = MExpr[expr]
        while at(p, TOK_SEMICOLON)
            advance!(p)
            if at(p, TOK_EOF) || at(p, TOK_RBRACE) || at(p, TOK_RBRACKET)
                push!(args, MSymbol("Null"))
                break
            end
            push!(args, parse_expr(p))
        end
        return MFunction("CompoundExpression", args)
    end
    expr
end

# ─── Top-level: parse a complete .m file ───

"""
    parse_mathematica(source::String) -> MExpr

Parse a single Mathematica expression from source text.
"""
function parse_mathematica(source::AbstractString)::MExpr
    tokens = tokenize(source)
    p = Parser(tokens)
    expr = parse_expr(p)
    # Allow trailing tokens (comments were already stripped)
    expr
end

"""
    parse_file_expressions(source::String) -> Vector{MExpr}

Parse notebook-generated RUBI files by complete `::Code::` cells, preserving
multiline rules and rejecting malformed or partially consumed cells. For the
older one-expression-per-line format, preserve the existing line-based path.
The latter still skips unparseable lines and needs a separate loss audit.
"""
function parse_file_expressions(source::String)::Vector{MExpr}
    expressions = MExpr[]

    # Notebook-generated RUBI files delimit complete initialization cells.
    # Parsing by line loses the left-hand side of multiline definitions.
    marker = "(* ::Code:: *)"
    if occursin(marker, source)
        cells = split(source, marker)
        for cell in cells[2:end]
            tokens = tokenize(cell)
            p = Parser(tokens)
            at(p, TOK_EOF) && continue
            expr = parse_expr(p)
            at(p, TOK_EOF) || throw(ParserError("Unexpected trailing tokens in code cell", current(p).line, current(p).col))
            push!(expressions, expr)
        end
        return expressions
    end

    for line in eachline(IOBuffer(source))
        stripped = strip(line)
        isempty(stripped) && continue

        # Skip pure comment lines
        startswith(stripped, "(*") && endswith(stripped, "*)") && continue

        # Some lines have inline comments — the tokenizer handles those
        try
            tokens = tokenize(stripped)
            p = Parser(tokens)
            if !at(p, TOK_EOF)
                expr = parse_expr(p)
                push!(expressions, expr)
            end
        catch e
            # Skip unparseable lines (comments, section headers, etc.)
            if !(e isa ParserError || e isa TokenizerError)
                rethrow()
            end
        end
    end

    expressions
end
