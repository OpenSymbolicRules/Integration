# Rule file writer: convert a .m rule file to OSR JSON

using JSON3

"""
    OPENMATH_SEMANTICS

OpenMath Content Dictionary symbol for every head the converter emits.  The
`openmath:<cd>#<name>` spelling is the one required by
`rule-file.schema.json`; RUBI's `Int` is an indefinite integral and its `Log`
is the natural logarithm, so they map to `calculus1#int` and `transc1#ln`
rather than to `calculus1#defint` and the base-taking `transc1#log`.  The
reciprocal, hyperbolic and inverse functions map to their `transc1` symbols
(RUBI spells the inverses `Asin`, `Atanh`, …); any other head is emitted as
`osr#<head>`.
"""
const OPENMATH_SEMANTICS = Dict(
    "Add" => "openmath:arith1#plus",
    "Subtract" => "openmath:arith1#minus",
    "Multiply" => "openmath:arith1#times",
    # Mathematical projection only. Keep the Star head for operational use.
    "Star" => "openmath:arith1#times",
    "Divide" => "openmath:arith1#divide",
    "Power" => "openmath:arith1#power",
    "Sqrt" => "openmath:arith1#root",
    "Int" => "openmath:calculus1#int",
    "Sin" => "openmath:transc1#sin",
    "Cos" => "openmath:transc1#cos",
    "Tan" => "openmath:transc1#tan",
    "Log" => "openmath:transc1#ln",
    "Exp" => "openmath:transc1#exp",
    "Cot" => "openmath:transc1#cot",
    "Sec" => "openmath:transc1#sec",
    "Csc" => "openmath:transc1#csc",
    "Sinh" => "openmath:transc1#sinh",
    "Cosh" => "openmath:transc1#cosh",
    "Tanh" => "openmath:transc1#tanh",
    "Coth" => "openmath:transc1#coth",
    "Sech" => "openmath:transc1#sech",
    "Csch" => "openmath:transc1#csch",
    "Asin" => "openmath:transc1#arcsin",
    "Acos" => "openmath:transc1#arccos",
    "Atan" => "openmath:transc1#arctan",
    "Acot" => "openmath:transc1#arccot",
    "Asec" => "openmath:transc1#arcsec",
    "Acsc" => "openmath:transc1#arccsc",
    "Asinh" => "openmath:transc1#arcsinh",
    "Acosh" => "openmath:transc1#arccosh",
    "Atanh" => "openmath:transc1#arctanh",
    "Acoth" => "openmath:transc1#arccoth",
    "Asech" => "openmath:transc1#arcsech",
    "Acsch" => "openmath:transc1#arccsch",
    "Abs" => "openmath:arith1#abs",
)

"""
    STRUCTURAL_HEADS

Heads the OSR expression language defines for itself rather than borrowing from
a mathematical domain: `List` is a collection and `Condition` pairs a pattern
with the test that admits it.  Neither carries domain meaning, so neither needs
an OpenMath binding.
"""
const STRUCTURAL_HEADS = Set(["List", "Condition"])

"""
    CONSTRAINT_COMBINATORS

Constraint heads whose operands are themselves constraints rather than
expressions.
"""
const CONSTRAINT_COMBINATORS = Set(["Not", "And", "Or", "If"])

"""
    WILDCARD_HEAD

Spelling of a pattern variable standing in operator position, as in the RUBI
rules that match any of the six trigonometric heads at once.  It names a
binding rather than an operation, so it needs no OpenMath symbol.
"""
const WILDCARD_HEAD = r"(_{1,3}$)|(^[a-zA-Z][a-zA-Z0-9]*\.-?[0-9]*$)|(^~)"

is_wildcard_head(head::AbstractString) = occursin(WILDCARD_HEAD, head)

function _expression_heads!(heads::Set{String}, expression)
    expression isa AbstractVector || return heads
    isempty(expression) && return heads
    head = first(expression)
    head isa String || return heads
    if head == "With" && length(expression) == 3 && expression[2] isa AbstractVector &&
       !isempty(expression[2]) && first(expression[2]) == "List" &&
       all(binding -> binding isa AbstractVector && length(binding) == 3 &&
           first(binding) == "Set", expression[2][2:end])
        for binding in expression[2][2:end]
            _expression_heads!(heads, binding[3])
        end
        _expression_heads!(heads, expression[3])
        return heads
    end
    if !(head in STRUCTURAL_HEADS) && !is_wildcard_head(head)
        push!(heads, head)
    end
    if head == "Condition"
        # A guarded pattern: an expression and the test that admits it.
        length(expression) == 3 || return heads
        _expression_heads!(heads, expression[2])
        _constraint_heads!(heads, expression[3])
        return heads
    end
    operands = head in ("Lambda", "Forall", "Exists") ? expression[3:end] : expression[2:end]
    for operand in operands
        _expression_heads!(heads, operand)
    end
    return heads
end

"""
    _constraint_heads!(heads, constraint)

Collect the mathematical operators a constraint applies its predicates to.  The
predicate name itself is rule-language vocabulary and needs no OpenMath symbol,
and a combinator nests constraints rather than expressions.
"""
function _constraint_heads!(heads::Set{String}, constraint)
    constraint isa AbstractVector || return heads
    isempty(constraint) && return heads
    name = first(constraint)
    name isa String || return heads
    if name in CONSTRAINT_COMBINATORS
        for operand in constraint[2:end]
            _constraint_heads!(heads, operand)
        end
        return heads
    end
    for argument in constraint[2:end]
        _expression_heads!(heads, argument)
    end
    return heads
end

function rule_semantics(rules)
    heads = Set{String}()
    for rule in rules
        _expression_heads!(heads, rule["pattern"])
        _expression_heads!(heads, rule["result"])
        # A constraint applies its predicates to mathematical expressions, and
        # those expressions carry domain vocabulary just as a pattern does.
        for constraint in get(rule, "constraints", ())
            _constraint_heads!(heads, constraint)
        end
    end
    Dict(head => get(OPENMATH_SEMANTICS, head, "openmath:osr#" * head) for head in sort!(collect(heads)))
end


struct ConversionWarning
    file::String
    line::Int
    message::String
    expression::String
end

# `Star` is RUBI's evaluation-aware distribution operator. Do not invent an
# OpenMath symbol or silently replace it with multiplication in rule output.
contains_rubi_star(expr::MExpr) = expr isa MFunction &&
    (expr.head == "Star" || any(arg -> arg isa MExpr && contains_rubi_star(arg), expr.args))

contains_local_scope(expr::MExpr) = expr isa MFunction &&
    (expr.head in ("With", "Module", "Set") ||
     any(arg -> arg isa MExpr && contains_local_scope(arg), expr.args))

"""Audit `Int` notebook cells without writing rules or claiming semantic correctness."""
function audit_code_cells(source::AbstractString)
    cells = split(source, "(* ::Code:: *)")
    candidates = parsed = star = local_scope = 0
    failures = NamedTuple{(:ordinal, :message),Tuple{Int,String}}[]
    for cell in cells[2:end]
        occursin(r"^Int\s*\[", lstrip(cell)) || continue
        candidates += 1
        try
            expressions = parse_file_expressions("(* ::Code:: *)" * cell)
            length(expressions) == 1 || error("Expected one expression in rule cell")
            parsed += 1
            any(contains_rubi_star, expressions) && (star += 1)
            any(contains_local_scope, expressions) && (local_scope += 1)
        catch e
            push!(failures, (ordinal=candidates, message=sprint(showerror, e)))
        end
    end
    (; candidates, parsed, star, local_scope, failures)
end

struct RuleConversionResult
    output_path::String
    section::String
    title::String
    rule_count::Int
    warnings::Vector{ConversionWarning}
end

"""
    rubi_provenance(relative_source_path, rule_id) -> Dict

Return machine-readable provenance for one rule converted from the pinned Rubi
source file. The source-relative path and original ordinal form a stable
locator within the source corpus.
"""
function rubi_source_version(source_path::AbstractString)
    dir = dirname(abspath(source_path))
    while true
        paclet = joinpath(dir, "PacletInfo.m")
        if isfile(paclet)
            found = match(r"\bVersion\s*->\s*\"([^\"]+)\"", read(paclet, String))
            return found === nothing ? nothing : String(found.captures[1])
        end
        parent = dirname(dir)
        parent == dir && return nothing
        dir = parent
    end
end

function rubi_provenance(relative_source_path::AbstractString, rule_id::Integer;
                         version::Union{Nothing,AbstractString}=nothing)::Dict{String,Any}
    source = Dict{String,Any}(
        "name" => "Rubi",
        "locator" => string(replace(relative_source_path, '\\' => '/'), "#", rule_id),
    )
    version === nothing || (source["version"] = String(version))
    Dict{String,Any}(
        "method" => "converted",
        "sources" => Any[source],
    )
end

"""
    convert_rule_file(source_path::String; output_dir::String="rules") -> RuleConversionResult

Convert a single Mathematica .m rule file to a OSR JSON rule file.
"""
function convert_rule_file(source_path::String; output_dir::String="rules")::RuleConversionResult
    source = read(source_path, String)
    filename = basename(source_path)
    section = extract_section_number(source_path)
    title = extract_title(source_path)

    # Compute relative path from the IntegrationRules directory
    rel_path = source_path
    idx = findfirst("IntegrationRules/", source_path)
    if idx !== nothing
        rel_path = source_path[idx.start + length("IntegrationRules/"):end]
    end
    # Also try matching from the base vendor path
    idx2 = findfirst("IntegrationRules" * ('/' |> string), rel_path)

    output_path = mathematica_path_to_osr(rel_path; prefix=output_dir)
    identity = source_identity(rel_path)
    source_version = rubi_source_version(source_path)

    warnings = ConversionWarning[]
    rules = Dict{String,Any}[]

    # Parse all expressions from the file
    expressions = try
        parse_file_expressions(source)
    catch e
        push!(warnings, ConversionWarning(source_path, 0, "Failed to parse file: $e", ""))
        return RuleConversionResult(output_path, section, title, 0, warnings)
    end

    if any(contains_rubi_star, expressions)
        push!(warnings, ConversionWarning(source_path, 0,
            "RUBI Star has no reviewed OSR mapping; the file was not converted", ""))
        return RuleConversionResult(output_path, section, title, 0, warnings)
    end

    if any(contains_local_scope, expressions)
        push!(warnings, ConversionWarning(source_path, 0,
            "Local binding semantics are not yet validated; the file was not converted", ""))
        return RuleConversionResult(output_path, section, title, 0, warnings)
    end

    # Extract rule definitions (SetDelayed with Int on LHS)
    rule_id = 0
    for expr in expressions
        if expr isa MFunction && expr.head == "SetDelayed"
            lhs = expr.args[1]
            if lhs isa MFunction && lhs.head == "Int"
                rule_id += 1
                try
                    rule = rule_to_osr(expr, rule_id)
                    rule["provenance"] = rubi_provenance(rel_path, rule_id; version=source_version)
                    push!(rules, rule)
                catch e
                    push!(warnings, ConversionWarning(
                        source_path, 0,
                        "Failed to convert rule $rule_id: $e",
                        ""
                    ))
                end
            elseif occursin("(* ::Code:: *)", source)
                push!(warnings, ConversionWarning(source_path, 0,
                    "Unsupported definition in code cell; the file was not converted", ""))
            end
        elseif occursin("(* ::Code:: *)", source)
            push!(warnings, ConversionWarning(source_path, 0,
                "Unsupported non-rule code cell; the file was not converted", ""))
        end
    end

    if !isempty(warnings)
        return RuleConversionResult(output_path, section, title, 0, warnings)
    end

    # Build the OSR rule file JSON
    osr_file = Dict{String,Any}(
        "\$schema" => "open-symbolic-rules/v0.1",
        "identity" => identity,
        "section" => section,
        "title" => title,
        "semantics" => rule_semantics(rules),
        "rules" => rules,
    )

    # Write output
    mkpath(dirname(output_path))
    open(output_path, "w") do io
        JSON3.pretty(io, osr_file; allow_inf=false)
        println(io)  # trailing newline
    end

    RuleConversionResult(output_path, section, title, length(rules), warnings)
end

"""
    convert_all_rules(vendor_path::String; output_dir::String="rules") -> Vector{RuleConversionResult}

Convert all .m rule files from the Rubi vendor submodule to OSR JSON.
"""
function convert_all_rules(vendor_path::String; output_dir::String="rules")::Vector{RuleConversionResult}
    rules_dir = joinpath(vendor_path, "Rubi", "IntegrationRules")
    if !isdir(rules_dir)
        error("IntegrationRules directory not found: $rules_dir")
    end

    # Find all .m files, sorted
    m_files = String[]
    for (root, dirs, files) in walkdir(rules_dir)
        for f in files
            if endswith(f, ".m")
                push!(m_files, joinpath(root, f))
            end
        end
    end
    sort!(m_files)

    mktempdir() do staging
        results = RuleConversionResult[]
        for (i, m_file) in enumerate(m_files)
            rel = replace(m_file, rules_dir * "/" => "")
            print("  [$i/$(length(m_files))] $rel")
            result = convert_rule_file(m_file; output_dir=staging)
            println(" → $(result.rule_count) rules" *
                    (isempty(result.warnings) ? "" : " ($(length(result.warnings)) warnings)"))
            for warning in result.warnings
                println(stderr, "  WARNING $(warning.file):$(warning.line): $(warning.message)")
            end
            push!(results, result)
        end

        total_rules = sum(r.rule_count for r in results)
        total_warnings = sum(length(r.warnings) for r in results)
        println("\nSummary: $total_rules rules converted from $(length(results)) files ($total_warnings warnings)")
        total_warnings == 0 || error("RUBI conversion incomplete: $total_warnings warnings; output was not changed")

        published = RuleConversionResult[]
        for result in results
            target = joinpath(output_dir, relpath(result.output_path, staging))
            mkpath(dirname(target))
            cp(result.output_path, target; force=true)
            push!(published, RuleConversionResult(target, result.section, result.title,
                result.rule_count, result.warnings))
        end
        published
    end
end
