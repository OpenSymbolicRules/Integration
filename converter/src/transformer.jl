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
    # BigInt values are emitted as Float64 for JSON compatibility
    expr.value isa BigInt ? Float64(expr.value) : expr.value
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

function to_osr(expr::MFunction)
    head = map_operator(expr.head)
    args = [to_osr(a) for a in expr.args]

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

    entry = Dict{String,Any}(
        "id" => id,
        "pattern" => to_osr(parts.pattern),
    )

    # constraints is required by the schema (even if empty)
    entry["constraints"] = [to_osr(c) for c in parts.constraints]

    entry["result"] = to_osr(parts.result)

    entry
end

"""
    resolve_num_steps(expr::MExpr) -> Int

Resolve num_steps from a test tuple. Handles:
- Plain integers: return directly
- Conditional: If[GreaterEqual[\$VersionNumber, n], a, b] → use branch `a` (latest Mathematica)
- Other expressions: return 0 as fallback
"""
function resolve_num_steps(expr::MExpr)::Int
    if expr isa MInteger
        val = expr.value
        return val isa BigInt ? Int(val) : val
    end
    # Handle If[condition, then, else] — pick the "then" branch (latest version)
    if expr isa MFunction && expr.head == "If" && length(expr.args) >= 3
        then_branch = expr.args[2]
        if then_branch isa MInteger
            val = then_branch.value
            return val isa BigInt ? Int(val) : val
        end
    end
    0  # fallback
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

    integrand = to_osr(expr.args[1])
    variable = to_osr(expr.args[2])
    num_steps = resolve_num_steps(expr.args[3])
    antiderivative = to_osr(expr.args[4])

    entry = Dict{String,Any}(
        "id" => id,
        "expression" => integrand,
        "variable" => variable isa AbstractString ? variable : string(variable),
        "num_steps" => num_steps,
        "expected_result" => antiderivative,
    )

    entry
end
