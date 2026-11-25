# AST → OSR-Expr transformer
# Converts MathematicaExpr tree to JSON-compatible nested arrays/values

"""
    to_osr(expr::MExpr) -> Any

Convert a MathematicaExpr AST node to OSR-Expr format.
Returns JSON-compatible values: arrays, strings, numbers.

OSR-Expr format: ["Operator", arg1, arg2, ...]
Atoms: strings for symbols/wildcards, numbers for integers/reals.
"""
function to_osr(expr::MSymbol)
    name = map_operator(expr.name)
    name
end

function to_osr(expr::MInteger)
    # JSON3.pretty rounds BigInt through floating point; reject instead of
    # silently changing an exact integer. Other integers remain exact.
    expr.value isa BigInt && error("Integer exceeds the exact JSON writer range")
    expr.value
end

function to_osr(expr::MReal)
    expr.value
end

function to_osr(expr::MString)
    expr.value
end

function to_osr(expr::MPattern)
    map_wildcard(expr.name, expr.blank_type, expr.type_head)
end

function to_osr(expr::MApply)
    throw(ArgumentError("Compound application heads have no reviewed OSR mapping"))
end

function to_osr(expr::MPrime)
    throw(ArgumentError("Prime notation has no reviewed OSR mapping"))
end

function to_osr(expr::MFunction, convert_child=to_osr)
    head = map_operator(expr.head)
    args = Any[convert_child(a) for a in expr.args]

    # Special handling for Rational[a, b] → emit as fraction
    if head == "Rational" && length(args) == 2
        num = args[1]
        den = args[2]
        # If both are integers, emit as ["Divide", num, den]
        if num isa Integer && den isa Integer
            return Any["Divide", num, den]
        end
    end

    # Flatten nested Plus/Times (Mathematica is n-ary)
    if head in ("Add", "Multiply")
        flat_args = Any[]
        for a in args
            if a isa AbstractVector && !isempty(a) && a[1] == head
                append!(flat_args, a[2:end])
            else
                push!(flat_args, a)
            end
        end
        return Any[head; flat_args]
    end

    Any[head; args]
end

"""
    extract_rule_parts(expr::MExpr) -> NamedTuple

Extract pattern, constraints, and result from a parsed RUBI rule definition.
Input is a SetDelayed node: Int[pattern, x_Symbol] := result /; condition

Returns: (pattern=..., constraints=[...], result=..., var=...)
"""
function extract_rule_parts(expr::MExpr)
    if !(expr isa MFunction && expr.head == "SetDelayed")
        error("Expected SetDelayed, got: $(typeof(expr))")
    end

    lhs = expr.args[1]
    rhs = expr.args[2]

    # LHS should be Int[pattern, x_Symbol]
    if !(lhs isa MFunction && lhs.head == "Int")
        error("Expected Int[...] on LHS, got: $(lhs)")
    end

    pattern = lhs.args[1]
    var = lhs.args[2]  # x_Symbol typically

    # RHS may be wrapped in Condition: result /; test
    constraints = MExpr[]
    result = rhs
    if rhs isa MFunction && rhs.head == "Condition"
        result = rhs.args[1]
        condition = rhs.args[2]
        constraints = split_and_conditions(condition)
    end

    (pattern=pattern, constraints=constraints, result=result, var=var)
end

"""
    split_and_conditions(expr::MExpr) -> Vector{MExpr}

Split a condition expression joined by && into individual conditions.
"""
function split_and_conditions(expr::MExpr)::Vector{MExpr}
    if expr isa MFunction && expr.head == "And"
        result = MExpr[]
        for arg in expr.args
            append!(result, split_and_conditions(arg))
        end
        return result
    end
    [expr]
end

"""
    rule_to_osr(expr::MExpr, id::Int) -> Dict

Convert a parsed RUBI rule definition to a OSR rule entry dict.
"""
function rule_to_osr(expr::MExpr, id::Int)::Dict{String,Any}
    parts = extract_rule_parts(expr)

    # RUBI writes an integration rule as `Int[integrand, x_Symbol] := ...`.
    # The pattern is that whole application, not just the integrand: it is what
    # binds the integration variable, so that the result and the constraints
    # refer to a binding rather than to a free symbol, and it is what restricts
    # the rule to an actual integral of an actual variable.
    entry = Dict{String,Any}(
        "id" => id,
        "pattern" => Any["Int", to_osr(parts.pattern), to_osr(parts.var)],
    )

    # constraints is required by the schema (even if empty)
    entry["constraints"] = [to_osr(c) for c in parts.constraints]

    entry["result"] = to_osr(parts.result)

    entry
end

# All conditional counts at the fixture pin compare $VersionNumber with 8, 9
# or 11. The companion index also publishes the complete source condition.
const FIXTURE_LANGUAGE_VERSION = 11

function resolve_num_steps(expr::MExpr)::Int
    expr isa MInteger && return Int(expr.value)
    if expr isa MFunction && expr.head == "If" && length(expr.args) == 3
        guard, yes, no = expr.args
        if guard isa MFunction && length(guard.args) == 2 && yes isa MInteger && no isa MInteger
            variable, bound = guard.args
            if variable isa MSymbol && variable.name == raw"$VersionNumber" && bound isa MInteger
                if guard.head == "Less"
                    return Int(FIXTURE_LANGUAGE_VERSION < bound.value ? yes.value : no.value)
                elseif guard.head == "GreaterEqual"
                    return Int(FIXTURE_LANGUAGE_VERSION >= bound.value ? yes.value : no.value)
                end
            end
        end
    end
    throw(ArgumentError("Unsupported fixture step count: $expr"))
end

# Fixtures can transcribe formal and held results that executable rules cannot use.
fixture_expr(expr::MExpr) = to_osr(expr)
fixture_expr(expr::MInteger) = expr.value
fixture_expr(expr::MFunction) = to_osr(expr, fixture_expr)

function fixture_expr(expr::MApply)
    head = expr.head
    if head isa MFunction && head.head == "Defer" && length(head.args) == 1 &&
       only(head.args) isa MSymbol && only(head.args).name == "Subst" && length(expr.args) == 3
        return Any["Apply", Any["Defer", "Subst"], Any["List", map(fixture_expr, expr.args)...]]
    end

    length(expr.args) == 1 || throw(ArgumentError("Unsupported compound fixture application"))
    if head isa MPrime
        order = 0
        while head isa MPrime
            order += 1
            head = head.expr
        end
        func = head
    elseif head isa MApply && head.head isa MFunction && head.head.head == "Derivative" &&
           length(head.head.args) == 1 && length(head.args) == 1
        order = fixture_expr(only(head.head.args))
        func = only(head.args)
    else
        throw(ArgumentError("Unsupported compound fixture head"))
    end
    func isa MSymbol || throw(ArgumentError("Expected a named unary function in fixture derivative"))
    derivative = Any["Apply", Any["Derivative", order], Any["List", fixture_expr(func)]]
    Any["Apply", derivative, Any["List", fixture_expr(only(expr.args))]]
end

"""
    test_tuple_to_osr(expr::MExpr, id::Int) -> Dict

Convert a parsed test tuple {integrand, variable, num_steps, antiderivative}
to a OSR test entry dict.
"""
function test_tuple_to_osr(expr::MExpr, id::Int)::Dict{String,Any}
    if !(expr isa MFunction && expr.head == "List" && length(expr.args) >= 4)
        error("Expected {integrand, variable, num_steps, antiderivative}, got $(typeof(expr))")
    end

    integrand = fixture_expr(expr.args[1])
    expr.args[2] isa MSymbol || throw(ArgumentError("Expected a symbol as the fixture variable"))
    variable = expr.args[2].name
    num_steps = resolve_num_steps(expr.args[3])
    antiderivative = fixture_expr(expr.args[4])

    entry = Dict{String,Any}(
        "id" => id,
        "expression" => integrand,
        "variable" => variable,
        "num_steps" => num_steps,
        "expected_result" => antiderivative,
    )

    entry
end
