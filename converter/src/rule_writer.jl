# Rule file writer: convert a .m rule file to PIRF JSON

using JSON3

struct ConversionWarning
    file::String
    line::Int
    message::String
    expression::String
end

struct RuleConversionResult
    output_path::String
    section::String
    title::String
    rule_count::Int
    warnings::Vector{ConversionWarning}
end

"""
    convert_rule_file(source_path::String; output_dir::String="rules") -> RuleConversionResult

Convert a single Mathematica .m rule file to a PIRF JSON rule file.
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

    output_path = mathematica_path_to_pirf(rel_path; prefix=output_dir)

    warnings = ConversionWarning[]
    rules = Dict{String,Any}[]

    # Parse all expressions from the file
    expressions = try
        parse_file_expressions(source)
    catch e
        push!(warnings, ConversionWarning(source_path, 0, "Failed to parse file: $e", ""))
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
                    rule = rule_to_pirf(expr, rule_id)
                    push!(rules, rule)
                catch e
                    push!(warnings, ConversionWarning(
                        source_path, 0,
                        "Failed to convert rule $rule_id: $e",
                        ""
                    ))
                end
            end
        end
    end

    # Build the OSR rule file JSON
    pirf_file = Dict{String,Any}(
        "\$schema" => "open-symbolic-rules/v0.1",
        "section" => section,
        "title" => title,
        "semantics" => Dict(
            "Int" => "openmath:calculus1.defint",
            "Sin" => "openmath:transc1.sin",
            "Cos" => "openmath:transc1.cos",
            "Tan" => "openmath:transc1.tan",
            "Log" => "openmath:transc1.log",
            "Exp" => "openmath:transc1.exp"
        ),
        "rules" => rules,
    )

    # Write output
    mkpath(dirname(output_path))
    open(output_path, "w") do io
        JSON3.pretty(io, pirf_file; allow_inf=false)
        println(io)  # trailing newline
    end

    RuleConversionResult(output_path, section, title, length(rules), warnings)
end

"""
    convert_all_rules(vendor_path::String; output_dir::String="rules") -> Vector{RuleConversionResult}

Convert all .m rule files from the Rubi vendor submodule to PIRF JSON.
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

    results = RuleConversionResult[]
    for (i, m_file) in enumerate(m_files)
        rel = replace(m_file, rules_dir * "/" => "")
        print("  [$i/$(length(m_files))] $rel")
        result = convert_rule_file(m_file; output_dir=output_dir)
        println(" → $(result.rule_count) rules" *
                (isempty(result.warnings) ? "" : " ($(length(result.warnings)) warnings)"))
        push!(results, result)
    end

    total_rules = sum(r.rule_count for r in results)
    total_warnings = sum(length(r.warnings) for r in results)
    println("\nSummary: $total_rules rules converted from $(length(results)) files ($total_warnings warnings)")

    results
end
