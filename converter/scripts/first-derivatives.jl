# Normalize the first-order function applications of release section 9.1 into
# the same Apply/Derivative/List representation as the reference fixtures.
using RubiConverter: MExpr, MApply, MPrime, MPattern, MSymbol, MFunction, MInteger

function collect_primed_names!(names, node)
    if node isa MApply && node.head isa MPrime && node.head.expr isa MPattern
        pat = node.head.expr
        if pat.blank_type == :blank && isnothing(pat.type_head) && occursin(r"^[a-z][a-zA-Z0-9]*$", pat.name)
            push!(names, pat.name)
        end
    elseif node isa MFunction
        foreach(arg -> collect_primed_names!(names, arg), node.args)
    end
end

function prepare_first_derivatives(expr)
    names = Set{String}()
    collect_primed_names!(names, first(expr.args))
    isempty(names) && return expr

    apply(head, arg) = MFunction("Apply", [head, MFunction("List", [arg])])
    function lower(node)
        if node isa MApply
            head = node.head
            head isa MPrime && length(node.args) == 1 || error("Expected a unary first derivative")
            f = head.expr
            (f isa MSymbol || (f isa MPattern && f.blank_type == :blank && isnothing(f.type_head))) &&
                f.name in names || error("Expected a bound function in first derivative")
            derivative = apply(MFunction("Derivative", [MInteger(1)]), f)
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
            # No new local binders, held expressions or unbound function heads.
            name in ("SetDelayed", "Int", "Condition", "FreeQ", "List", "Plus", "Times", "Power", "Log") ||
                error("Unsupported head in first-derivative rule: $name")
            return MFunction(name, map(lower, node.args))
        end
        node
    end
    lower(expr)
end
