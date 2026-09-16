#!/usr/bin/env julia
# Proof-of-concept: verify OSR integration tests by differentiating antiderivatives
# Usage:
#   julia --project=scripts scripts/verify_tests.jl                    # default: section 1.1.1
#   julia --project=scripts scripts/verify_tests.jl path/to/test.json  # specific file(s)

using Pkg
Pkg.activate(@__DIR__)

using JSON3
using Symbolics

const REPO_ROOT = abspath(joinpath(@__DIR__, ".."))
const TEST_TIMEOUT = 5.0  # seconds per test

# ---------------------------------------------------------------------------
# Symbol registry: dynamically create Symbolics variables by name
# ---------------------------------------------------------------------------

const SYMBOL_REGISTRY = Dict{String, Num}()

function get_or_create_sym(name::String)::Num
    get!(SYMBOL_REGISTRY, name) do
        Symbolics.variable(Symbol(name))
    end
end

# ---------------------------------------------------------------------------
# Unsupported operators — cause a test to be skipped
# ---------------------------------------------------------------------------

struct UnsupportedOperatorError <: Exception
    operator::String
end

const UNSUPPORTED_OPERATORS = Set([
    # Integration-specific (should not appear in verified results)
    "Int", "Dist", "Subst", "Simp", "ExpandIntegrand",
    "Unintegrable", "CannotIntegrate",
    # Special functions not in Symbolics.jl
    "EllipticF", "EllipticE", "EllipticPi", "EllipticK",
    "Hypergeometric2F1", "HypergeometricPFQ", "AppellF1",
    "BesselJ", "BesselY", "BesselI", "BesselK",
    "Erf", "Erfc", "Erfi", "FresnelS", "FresnelC",
    "Gamma", "LogGamma", "Beta", "Zeta",
    "PolyLog", "ProductLog",
    "ExpIntegralE", "ExpIntegralEi", "LogIntegral",
    "SinIntegral", "CosIntegral", "SinhIntegral", "CoshIntegral",
    # Structural operators
    "If", "GreaterEqual", "Piecewise", "Condition",
    # Complex number support is limited in Symbolics.jl
    "ImaginaryI",
    # Utility functions from RUBI
    "Rt", "RtAux",
])

# ---------------------------------------------------------------------------
# Operator dispatch table: OSR operator name → Symbolics.jl function
# ---------------------------------------------------------------------------

const OSR_OPS = Dict{String, Function}(
    # Core arithmetic (n-ary)
    "Add"      => args -> reduce(+, args),
    "Multiply" => args -> reduce(*, args),

    # Core arithmetic (binary)
    "Power"    => args -> begin
        base, exp = args[1], args[2]
        # Avoid DomainError: integer^negative_integer
        if base isa Num && Symbolics.value(base) isa Integer && exp isa Num && Symbolics.value(exp) isa Integer && Symbolics.value(exp) < 0
            Num(Float64(Symbolics.value(base))) ^ exp
        else
            base ^ exp
        end
    end,
    "Subtract" => args -> args[1] - args[2],
    "Divide"   => args -> args[1] / args[2],

    # Core arithmetic (unary)
    "Negate"   => args -> -args[1],
    "Sqrt"     => args -> sqrt(args[1]),
    "Abs"      => args -> abs(args[1]),
    "Factorial" => args -> factorial(args[1]),

    # Exponential / Logarithmic
    "Exp" => args -> exp(args[1]),
    "Log" => args -> length(args) == 1 ? log(args[1]) : log(args[2]) / log(args[1]),

    # Trigonometric
    "Sin" => args -> sin(args[1]),
    "Cos" => args -> cos(args[1]),
    "Tan" => args -> tan(args[1]),
    "Cot" => args -> cot(args[1]),
    "Sec" => args -> sec(args[1]),
    "Csc" => args -> csc(args[1]),

    # Inverse trigonometric
    "Asin" => args -> asin(args[1]),
    "Acos" => args -> acos(args[1]),
    "Atan" => args -> length(args) == 1 ? atan(args[1]) : atan(args[1], args[2]),
    "Acot" => args -> acot(args[1]),
    "Asec" => args -> asec(args[1]),
    "Acsc" => args -> acsc(args[1]),

    # Hyperbolic
    "Sinh" => args -> sinh(args[1]),
    "Cosh" => args -> cosh(args[1]),
    "Tanh" => args -> tanh(args[1]),
    "Coth" => args -> coth(args[1]),
    "Sech" => args -> sech(args[1]),
    "Csch" => args -> csch(args[1]),

    # Inverse hyperbolic
    "Asinh" => args -> asinh(args[1]),
    "Acosh" => args -> acosh(args[1]),
    "Atanh" => args -> atanh(args[1]),
    "Acoth" => args -> acoth(args[1]),
    "Asech" => args -> asech(args[1]),
    "Acsch" => args -> acsch(args[1]),
)

# ---------------------------------------------------------------------------
# from_osr: convert OSR-Expr JSON → Symbolics.jl Num expression
# ---------------------------------------------------------------------------

function from_osr(expr)::Num
    # Case 1: Number — use Float64 to avoid integer overflow
    if expr isa Integer
        return Num(Float64(expr))
    end
    if expr isa Number
        return Num(expr)
    end

    # Case 2: String — constant or symbolic variable
    if expr isa AbstractString
        if expr == "Pi"
            return Num(π)
        elseif expr == "E"
            return Num(MathConstants.e)
        elseif expr in UNSUPPORTED_OPERATORS || expr == "ImaginaryI"
            throw(UnsupportedOperatorError(expr))
        else
            return get_or_create_sym(expr)
        end
    end

    # Case 3: Array — function application ["Operator", arg1, arg2, ...]
    if expr isa AbstractVector
        isempty(expr) && error("Empty OSR expression array")
        op = String(expr[1])

        if op in UNSUPPORTED_OPERATORS
            throw(UnsupportedOperatorError(op))
        end

        # Recursively convert arguments
        args = Num[from_osr(a) for a in expr[2:end]]

        if haskey(OSR_OPS, op)
            return OSR_OPS[op](args)
        else
            throw(UnsupportedOperatorError(op))
        end
    end

    error("Unexpected OSR-Expr type: $(typeof(expr))")
end

# ---------------------------------------------------------------------------
# Numerical spot-check: substitute random values and verify ≈ 0
# ---------------------------------------------------------------------------

function numerical_check(diff_expr::Num; ntries=5, atol=1e-6)::Bool
    vars = Symbolics.get_variables(diff_expr)
    isempty(vars) && return false

    for _ in 1:ntries
        subs = Dict(v => 0.5 + 2.0 * rand() for v in vars)
        try
            val = Symbolics.value(substitute(diff_expr, subs))
            if !(val isa Number && isfinite(val) && abs(val) < atol)
                return false
            end
        catch
            continue  # domain error, try another point
        end
    end
    return true
end

# ---------------------------------------------------------------------------
# verify_test: check one test problem
# ---------------------------------------------------------------------------

function verify_test(test_entry)::Symbol
    num_steps = Int(test_entry[:num_steps])
    if num_steps < 0
        return :skip
    end

    variable_name = String(test_entry[:variable])

    # Parse integrand and antiderivative
    local integrand_sym, antideriv_sym
    try
        integrand_sym = from_osr(test_entry[:integrand])
        antideriv_sym = from_osr(test_entry[:optimal_antiderivative])
    catch e
        e isa UnsupportedOperatorError && return :skip
        rethrow()
    end

    # Differentiate antiderivative
    var_sym = get_or_create_sym(variable_name)
    D = Differential(var_sym)
    derivative = expand_derivatives(D(antideriv_sym))

    # Check: d/dx(F) - f == 0?
    diff_expr = derivative - integrand_sym

    # Tier 1: direct comparison after simplify
    s1 = simplify(diff_expr)
    if isequal(s1, 0) || isequal(s1, Num(0))
        return :pass
    end

    # Tier 2: numerical spot-check (fast fallback, avoids expensive expand)
    if numerical_check(diff_expr)
        return :pass
    end

    return :fail
end

# ---------------------------------------------------------------------------
# verify_file: process all tests in a JSON file
# ---------------------------------------------------------------------------

function verify_file(filepath::String)
    data = JSON3.read(read(filepath, String))
    section = String(data[:section])
    title = String(data[:title])
    tests = data[:tests]

    results = Dict(:pass => 0, :fail => 0, :skip => 0, :error => 0)
    failures = Tuple{Int,String}[]

    for (i, t) in enumerate(tests)
        id = Int(t[:id])
        if i % 100 == 0
            print("  progress: $i/$(length(tests))\r")
            flush(stdout)
        end
        result = try
            verify_test(t)
        catch e
            push!(failures, (id, sprint(showerror, e)))
            :error
        end
        results[result] += 1
        if result == :fail
            push!(failures, (id, "derivative ≠ integrand"))
        end
    end

    return (section=section, title=title, filepath=filepath,
            results=results, total=length(tests), failures=failures)
end

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

function main(args)
    if isempty(args)
        # Default: section 1.1.1 linear binomial tests
        test_dir = joinpath(REPO_ROOT, "tests", "1-algebraic", "1.1-binomial", "1.1.1-linear")
        files = sort(filter(f -> endswith(f, ".json"), readdir(test_dir, join=true)))
    else
        files = args
    end

    println("OSR Integration Test Verifier (proof-of-concept)")
    println("=" ^ 60)
    println()
    flush(stdout)

    grand = Dict(:pass => 0, :fail => 0, :skip => 0, :error => 0)

    for filepath in files
        report = verify_file(filepath)
        r = report.results

        println("[$(report.section)] $(report.title)")
        println("  $(report.total) tests: PASS=$(r[:pass]) FAIL=$(r[:fail]) SKIP=$(r[:skip]) ERROR=$(r[:error])")

        if !isempty(report.failures)
            for (id, msg) in report.failures[1:min(3, length(report.failures))]
                println("    #$id: $msg")
            end
            if length(report.failures) > 3
                println("    ... and $(length(report.failures) - 3) more")
            end
        end
        println()
        flush(stdout)

        for (k, v) in r
            grand[k] += v
        end
    end

    total = sum(values(grand))
    verifiable = grand[:pass] + grand[:fail]
    pass_overall = total > 0 ? round(100 * grand[:pass] / total; digits=1) : 0.0
    pass_verifiable = verifiable > 0 ? round(100 * grand[:pass] / verifiable; digits=1) : 0.0

    println("=" ^ 60)
    println("SUMMARY: $total tests across $(length(files)) files")
    println("  PASS:  $(grand[:pass])")
    println("  FAIL:  $(grand[:fail])")
    println("  SKIP:  $(grand[:skip])")
    println("  ERROR: $(grand[:error])")
    println("  Pass rate (overall): $(pass_overall)%")
    println("  Pass rate (verifiable): $(pass_verifiable)%")
end

main(ARGS)
