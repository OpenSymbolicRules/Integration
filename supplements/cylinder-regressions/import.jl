# Rebuild the selected tests from the pinned SymbolicIntegration.jl source, without executing it.
using JSON3, SHA

const cases = [
    ("j0-first-moment", 10:13), ("j1-second-moment", 14:17),
    ("y0-first-moment", 18:21), ("i0-first-moment", 22:25),
    ("k0-first-moment", 26:29), ("j0-third-moment", 31:35),
    ("j0-polynomial-expanded", 36:41), ("j0-polynomial-factored", 42:47),
    ("i0-third-moment", 53:57), ("k0-third-moment", 58:62),
    ("h1-first-moment", 64:67), ("h2-third-moment", 68:72),
]
const functions = Dict(:besselj => "BesselJ", :bessely => "BesselY",
                       :besseli => "BesselI", :besselk => "BesselK",
                       :hankelh1 => "HankelH1", :hankelh2 => "HankelH2")
const arithmetic = Dict(:+ => "Add", :- => "Subtract", :* => "Multiply",
                        :/ => "Divide", :^ => "Power")

function osr(node)
    node isa Int && return node
    node in (:x, :a) && return string(node)
    Meta.isexpr(node, :call) || error("Unsupported source expression $node")
    op, args... = node.args
    if Meta.isexpr(op, :., 2) && op.args[1] == :SpecialFunctions
        length(args) == 2 || error("Unexpected function arity in $node")
        head = functions[op.args[2].value]
    elseif op == :- && length(args) == 1
        return Any["Multiply", -1, osr(only(args))]
    else
        head = arithmetic[op]
    end
    return Any[head, map(osr, args)...]
end

function import_case(lines, (id, span))
    test = Meta.parse(join(lines[span], "\n"))
    Meta.isexpr(test, :macrocall, 3) && first(test.args) == Symbol("@test") || error(id)
    comparison = last(test.args)
    Meta.isexpr(comparison, :call, 3) && first(comparison.args) == :isequal || error(id)
    integral, primitive = comparison.args[2:3]
    Meta.isexpr(integral, :call, 4) && first(integral.args) == :integrate || error(id)
    integral.args[3:4] == [:x, :method] || error(id)
    return (; id, source_lines=[first(span), last(span)], variable="x",
            expression=osr(integral.args[2]), expected_result=osr(primitive))
end

function run(source_path)
    source = read(source_path)
    digest = bytes2hex(sha256(source))
    digest == "d31dd446a8f8cae6a7725f016b308bee23ab149014231183a94c3d6daa98fccc" ||
        error("Unexpected upstream file SHA-256: $digest")
    lines = split(String(source), '\n')
    metadata = (; source="https://github.com/JuliaSymbolics/SymbolicIntegration.jl",
                revision="3625e0e4bb1d78c0ce0acc038d75043aa48efdf1",
                path="test/methods/rule_based/test_special_functions.jl",
                source_sha256=digest, license="MIT",
                constraints=[["FreeQ", "a", "x"], ["GtQ", "a", 0], ["GtQ", "x", 0]])
    records = [import_case(lines, entry) for entry in cases]
    println("{")
    for (key, value) in pairs(metadata)
        println("  ", JSON3.write(string(key)), ": ", JSON3.write(value), ",")
    end
    println("  \"tests\": [")
    for (i, record) in enumerate(records)
        println("    {")
        fields = [JSON3.write(string(k)) * ": " * JSON3.write(v) for (k,v) in pairs(record)]
        println("      ", join(fields, ",\n      "))
        println(i == length(records) ? "    }" : "    },")
    end
    println("  ]\n}")
end

run(only(ARGS))
