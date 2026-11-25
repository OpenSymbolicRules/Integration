# Convert unary derivative applications of section 9.1 to the same curried
# Apply/Derivative/List representation as the reference fixtures.
using RubiConverter: MApply, MPrime, MPattern, MSymbol, MFunction, MInteger

plain_named_pattern(f) = f isa MPattern && f.blank_type == :blank &&
    isnothing(f.type_head) && occursin(r"^[a-z][a-zA-Z0-9]*$", f.name)

function derivative_parts(node::MApply)
    head = node.head
    length(node.args) == 1 || return nothing
    head isa MPrime && return (MInteger(1), head.expr)
    if head isa MApply && length(head.args) == 1 && head.head isa MFunction &&
       head.head.head == "Derivative" && length(head.head.args) == 1
        return (only(head.head.args), only(head.args))
    end
    nothing
end

function collect_derivative_bindings!(names, node, positive_orders)
    if node isa MApply
        parts = derivative_parts(node)
        isnothing(parts) && return
        order, f = parts
        if plain_named_pattern(f) && (node.head isa MPrime ||
           (plain_named_pattern(order) && order.name in positive_orders))
            push!(names, f.name)
        end
    elseif node isa MFunction
        foreach(arg -> collect_derivative_bindings!(names, arg, positive_orders), node.args)
    end
end

function positive_order_names(constraints)
    orders = Set{String}()
    for c in constraints
        c isa MFunction && c.head == "IGtQ" && length(c.args) == 2 || continue
        n, bound = c.args
        if n isa MSymbol && bound isa MInteger && iszero(bound.value)
            push!(orders, n.name)
        end
    end
    orders
end

function supported_order(order, positive_orders)
    order isa MInteger && return isone(order.value)
    if order isa MSymbol || plain_named_pattern(order)
        return order.name in positive_orders
    end
    # Rubi writes n-1 as Plus[n, Times[-1, 1]]. Its minimum value is zero.
    term = RubiConverter.to_osr(order)
    any(n -> term == ["Add", n, ["Multiply", -1, 1]], positive_orders)
end

function prepare_derivative_applications(expr)
    rule = RubiConverter.extract_rule_parts(expr)
    orders = positive_order_names(rule.constraints)
    names = Set{String}()
    collect_derivative_bindings!(names, rule.pattern, orders)
    isempty(names) && return expr
    rule.var isa MPattern && rule.var.type_head == "Symbol" || error("Expected a symbolic integration variable")
    variable = rule.var.name

    apply(head, arg) = MFunction("Apply", [head, MFunction("List", [arg])])
    function lower(node)
        if node isa MApply
            parts = derivative_parts(node)
            isnothing(parts) && error("Expected a unary derivative")
            order, f = parts
            supported_order(order, orders) || error("Derivative order requires a positive integer guard")
            (f isa MSymbol || plain_named_pattern(f)) && f.name in names ||
                error("Expected a bound function in derivative")
            derivative = apply(MFunction("Derivative", [order]), f)
            return apply(derivative, lower(only(node.args)))
        elseif node isa MFunction
            name = node.head
            wildcard = endswith(name, "_")
            binding = wildcard ? chop(name) : name
            if binding in names
                length(node.args) == 1 || error("Expected a unary application of $binding")
                f = wildcard ? MPattern(binding, :blank, nothing) : MSymbol(binding)
                return apply(f, lower(only(node.args)))
            end
            if name == "Int" && node !== first(expr.args)
                length(node.args) == 2 && node.args[2] isa MSymbol && node.args[2].name == variable ||
                    error("Residual integrals must retain the integration variable")
            elseif (name == "SetDelayed" && node !== expr) || (name == "Condition" && node !== last(expr.args))
                error("Unexpected nested definition or condition")
            end
            # Other scopes, held expressions and unbound function heads require review.
            name in ("SetDelayed", "Int", "Condition", "FreeQ", "And", "IGtQ", "List",
                     "Plus", "Times", "Power", "Log", "Sin", "Cos", "Star") ||
                error("Unsupported head in derivative rule: $name")
            return MFunction(name, map(lower, node.args))
        end
        node
    end
    lower(expr)
end

# These citations refer to a reviewed source file and a fixed proof revision.
# A later Rubi edit can reuse a cell ordinal with a different statement.
function annotate_derivative_section!(rules, omitted, digest)
    digest == "2087d3e21da88eaccb5d73b44d63c9071a56405df7fd0bbe320cc839213774df" || return
    for (i, cell) in pairs(omitted)
        if cell.ordinal in 16:18
            reason = cell.reason * ". The source coefficient a/(p+1) is undefined at p=q=-1 even when the guards hold (see upstream-bugs.md)"
            omitted[i] = merge(cell, (; reason))
        end
    end
    base = "https://github.com/OpenSymbolicRules/Integration/blob/eb539b2a2c589d254f90dc3b1c820b7fda2acf76/verification/"
    proofs = Dict(
        2  => ("exponentialParts", "RubiDerivativeRecurrences.lean#L43"),
        4  => ("sineParts",        "RubiDerivativeRecurrences.lean#L27"),
        5  => ("cosineParts",      "RubiDerivativeRecurrences.lean#L35"),
        19 => ("product",          "RubiDerivativePrimitives.lean#L13"),
        20 => ("quotient",         "RubiDerivativePrimitives.lean#L18"),
        21 => ("logQuotient",      "RubiDerivativePrimitives.lean#L23"),
    )
    for rule in rules
        haskey(proofs, rule["id"]) || continue
        name, location = proofs[rule["id"]]
        references = get!(rule, "references", Dict{String,String}())
        references["Lean (real, under the stated hypotheses)"] = "OSR.Rubi." * name
        references["Theorem statement"] = base * location
    end
end
