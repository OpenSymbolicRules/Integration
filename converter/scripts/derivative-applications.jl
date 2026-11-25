# Convert unary derivative applications of section 9.1 to the same curried
# Apply/Derivative/List representation as the reference fixtures.
using RubiConverter: MApply, MPrime, MPattern, MSymbol, MFunction, MInteger

const DERIVATIVE_SECTION = "9 Miscellaneous/9.1 Derivative integration rules.m"
const DERIVATIVE_DIGEST = "2087d3e21da88eaccb5d73b44d63c9071a56405df7fd0bbe320cc839213774df"

# These cells keep their full transcription in coverage.json, outside the loader.
function derivative_hold_reason(cell)
    cell in (3,6,7) && return "Negative derivative order needs a coherent primitive convention; the source does not ensure a nonzero divisor."
    cell in 16:18 && return "The source coefficient a/(p+1) is undefined at p=q=-1 even when the guards hold (see upstream-bugs.md)."
    cell in (1,8,10,11,13,14,15) && return "Source guards do not ensure the nonnegative integer derivative orders needed by calculus1#nthdiff, including the predecessor."
    nothing
end

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

function collect_derivative_bindings!(names, node, positive_orders; pinned_source=false)
    if node isa MApply
        parts = derivative_parts(node)
        isnothing(parts) && return
        order, f = parts
        if plain_named_pattern(f) && (pinned_source || node.head isa MPrime ||
           (plain_named_pattern(order) && order.name in positive_orders))
            push!(names, f.name)
        end
    elseif node isa MFunction
        foreach(arg -> collect_derivative_bindings!(names, arg, positive_orders; pinned_source), node.args)
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

function prepare_derivative_applications(expr; pinned_source=false)
    rule = RubiConverter.extract_rule_parts(expr)
    orders = positive_order_names(rule.constraints)
    names = Set{String}()
    collect_derivative_bindings!(names, rule.pattern, orders; pinned_source)
    isempty(names) && return expr
    rule.var isa MPattern && rule.var.type_head == "Symbol" || error("Expected a symbolic integration variable")
    variable = rule.var.name

    apply(head, arg) = MFunction("Apply", [head, MFunction("List", [arg])])
    function lower(node)
        if node isa MApply
            parts = derivative_parts(node)
            isnothing(parts) && error("Expected a unary derivative")
            order, f = parts
            pinned_source || supported_order(order, orders) || error("Derivative order requires a positive integer guard")
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
            if pinned_source && name in ("EqQ", "ILtQ", "FunctionOfQ", "SubstFor", "Subst", "SimplifyIntegrand")
                # Keep each Rubi helper and its operand order, including the dummy variable.
                return MFunction(name, map(lower, node.args))
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

# Restrictions supplement the original guards when interpreting a source order as
# an ordinary real derivative. Analytic assumptions and branch choices are in
# the linked theorem. Negative orders require an independently chosen primitive tower.
function order_and_divisor_guards(cell)
    guards = Any[]
    cell in (1,8,11,15,18) && push!(guards, ["IGtQ","n",0])
    cell in (10,11,13,14,15,17,18) && push!(guards, ["IGtQ","m",0])
    if cell == 3
        push!(guards, ["NeQ",["Multiply","b","p",["Log","F"]],0])
    elseif cell in (6,7)
        push!(guards, ["NeQ","b",0])
    elseif cell in 16:18
        push!(guards, ["NeQ",["Add","p",1],0])
    end
    guards
end

# These citations refer to a reviewed source file and a fixed proof revision.
# A later Rubi edit can reuse a cell ordinal with a different statement.
function annotate_derivative_section!(rules, omitted, digest)
    digest == DERIVATIVE_DIGEST || return
    base = "https://github.com/OpenSymbolicRules/Integration/blob/eb539b2a2c589d254f90dc3b1c820b7fda2acf76/verification/"
    proofs = Dict(
        2  => ("exponentialParts", "RubiDerivativeRecurrences.lean#L43"),
        4  => ("sineParts",        "RubiDerivativeRecurrences.lean#L27"),
        5  => ("cosineParts",      "RubiDerivativeRecurrences.lean#L35"),
        19 => ("product",          "RubiDerivativePrimitives.lean#L13"),
        20 => ("quotient",         "RubiDerivativePrimitives.lean#L18"),
        21 => ("logQuotient",      "RubiDerivativePrimitives.lean#L23"),
    )
    review_base = "https://github.com/OpenSymbolicRules/Integration/blob/e424343ca89ac941fce7a08e5c44e9dcc3c49077/verification/"
    substitutions = "RubiDerivativeSubstitutions.lean#L"
    recurrences = "RubiDerivativeRecurrences.lean#L"
    review = Dict(
        1 => ("predecessorDeriv", recurrences * "14"),
        3 => ("exponentialPrimitiveParts", recurrences * "63"),
        6 => ("sinePrimitiveParts", recurrences * "77"),
        7 => ("cosinePrimitiveParts", recurrences * "87"),
        8 => ("primitiveSubstitution", substitutions * "13"),
        9 => ("productSubstitution", substitutions * "19"),
        10 => ("productSubstitution", substitutions * "19"),
        11 => ("productSubstitution", substitutions * "19"),
        12 => ("leftPowerSubstitution", substitutions * "27"),
        13 => ("leftPowerSubstitution", substitutions * "27"),
        14 => ("rightPowerSubstitution", substitutions * "39"),
        15 => ("leftPowerSubstitution", substitutions * "27"),
        16 => ("twoPowerSubstitution", substitutions * "51"),
        17 => ("twoPowerSubstitution", substitutions * "51"),
        18 => ("twoPowerSubstitution", substitutions * "51"),
    )
    for (i, cell) in pairs(omitted)
        name, location = review[cell.ordinal]
        omitted[i] = merge(cell, (; order_and_divisor_guards=order_and_divisor_guards(cell.ordinal),
            real_interpretation=(; theorem="OSR.Rubi." * name, source=review_base * location)))
    end
    for rule in rules
        cell = rule["id"]
        name, location = haskey(proofs, cell) ? proofs[cell] : review[cell]
        url = haskey(proofs, cell) ? base : review_base
        references = get!(rule, "references", Dict{String,String}())
        references["Lean (real, under the stated hypotheses)"] = "OSR.Rubi." * name
        references["Theorem statement"] = url * location
    end
end
