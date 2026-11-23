#!/usr/bin/env julia
# Isolated candidate generation; never changes the production rules tree.
using RubiConverter
using JSON3

function has_expression_head(node, head)
    node isa AbstractVector || return false
    (!isempty(node) && node[1] == head) || any(child -> has_expression_head(child, head), node)
end

function rule_uses_head(rule, head)
    any(key -> has_expression_head(rule[key], head), ("pattern", "result", "constraints"))
end

function recover_empty_rules(rules_dir::AbstractString, vendor::AbstractString, output::AbstractString)
    rules_dir = realpath(rules_dir)
    vendor = realpath(vendor)
    output = abspath(output)
    ispath(output) && error("Candidate output already exists: $output")
    isdir(dirname(output)) || error("Candidate output parent must exist")
    parent = realpath(dirname(output))
    for protected in (rules_dir, vendor)
        rel = relpath(parent, protected)
        (rel == "." || !(first(splitpath(rel)) == "..")) &&
            error("Candidate output must be outside the rules and source trees")
    end
    meta = JSON3.read(read(joinpath(rules_dir, "meta.json"), String))
    results = Dict{String,Any}[]
    mkpath(output)
    for rawpath in meta["load_order"]
        path = String(rawpath)
        (isabspath(path) || ".." in splitpath(path)) && error("Invalid manifest path")
        doc = JSON3.read(read(joinpath(rules_dir, path), String))
        isempty(doc["rules"]) || continue
        identity = String(doc["identity"])
        startswith(identity, "rubi:") || error("Missing RUBI source identity")
        source_rel = identity[6:end] * ".m"
        (isabspath(source_rel) || ".." in splitpath(source_rel)) && error("Invalid source identity")
        source = joinpath(vendor, "Rubi", "IntegrationRules", source_rel)
        row = Dict{String,Any}("osr_file" => path, "source" => source_rel)
        if !isfile(source)
            row["status"] = "blocked"
            row["reason"] = "Source file not found"
        else
            result = RubiConverter.convert_rule_file(source;
                output_dir=joinpath(output, "rules"), experimental_rubi_extensions=true)
            if !isempty(result.warnings)
                row["status"] = "blocked"
                row["reason"] = join((w.message for w in result.warnings), "; ")
            else
                row["status"] = "candidate"
                row["rules"] = result.rule_count
                row["candidate_file"] = relpath(result.output_path, output)
                candidates = JSON3.read(read(result.output_path, String))["rules"]
                star_ids = [rule["id"] for rule in candidates if rule_uses_head(rule, "Star")]
                with_ids = [rule["id"] for rule in candidates if rule_uses_head(rule, "With")]
                row["syntax_features_detected"] = [head for (head, ids) in (("Star", star_ids), ("With", with_ids)) if !isempty(ids)]
                row["rules_with_star"] = length(star_ids)
                row["rules_with_with"] = length(with_ids)
                row["rule_ids_with_star"] = star_ids
                row["rule_ids_with_with"] = with_ids
            end
        end
        push!(results, row)
    end
    candidates = filter(x -> x["status"] == "candidate", results)
    revision = try
        strip(read(pipeline(`git -C $vendor rev-parse HEAD`; stderr=devnull), String))
    catch
        nothing
    end
    report = Dict{String,Any}(
        "status" => "experimental; not verified or approved for execution",
        "feature_inventory_scope" => "Star and With syntax only; other required capabilities are not assessed",
        "source_revision" => revision,
        "source_version" => RubiConverter.rubi_source_version(joinpath(vendor, "Rubi", "IntegrationRules", "source.m")),
        "candidate_files" => length(candidates),
        "candidate_rules" => sum((x["rules"] for x in candidates); init=0),
        "blocked_files" => length(results) - length(candidates),
        "files" => results,
    )
    open(joinpath(output, "report.json"), "w") do io
        JSON3.pretty(io, report)
        println(io)
    end
    report
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 3 || error("Usage: julia --project=converter converter/scripts/recover-empty.jl RULES_DIR VENDOR_RUBI NEW_OUTPUT_DIR")
    report = recover_empty_rules(ARGS...)
    println("Experimental candidates: $(report["candidate_rules"]) rules in $(report["candidate_files"]) files; $(report["blocked_files"]) blocked. Not approved for execution.")
end
