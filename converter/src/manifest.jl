# Manifest generator: update meta.json with load_order, counts, and converter metadata

using JSON3
using Dates

"""
    update_manifest(meta_path::String, rules_dir::String, tests_dir::String, vendor_rubi_path::String)

Update the meta.json file with:
- load_order: preserve the reviewed file sequence already in the manifest
- rule_count: total rules across all files
- test_count: total test problems across all test files
- converter: tool metadata (name, version, source commit, timestamp)
"""
function update_manifest(meta_path::String, rules_dir::String, tests_dir::String, vendor_rubi_path::String)
    # Read existing meta.json to preserve hand-crafted fields
    raw = JSON3.read(read(meta_path, String))
    meta = Dict{String,Any}(string(k) => v for (k, v) in pairs(raw))

    # Enumerate the whole corpus for counts, including intentionally unloaded files.
    rule_files = String[]
    if isdir(rules_dir)
        for (root, dirs, files) in walkdir(rules_dir)
            for f in files
                if endswith(f, ".json") && f != "meta.json"
                    rel = relpath(joinpath(root, f), rules_dir)
                    push!(rule_files, rel)
                end
            end
        end
    end
    sort!(rule_files)

    # The reviewed sequence is not section order and may omit unloaded files.
    haskey(meta, "load_order") || error("Manifest has no reviewed load_order")
    order = meta["load_order"]
    order isa AbstractVector || error("Manifest load_order must be an array")
    all(item -> item isa AbstractString, order) || error("Manifest load_order entries must be strings")
    length(unique(order)) == length(order) || error("Manifest load_order contains duplicates")
    available = Set(rule_files)
    all(item -> item in available, order) || error("Manifest load_order references missing files")

    # Count total rules across all rule files
    total_rules = 0
    for rf in rule_files
        full_path = joinpath(rules_dir, rf)
        try
            data = JSON3.read(read(full_path, String))
            if haskey(data, :rules)
                total_rules += length(data[:rules])
            end
        catch
            # Skip files that can't be parsed
        end
    end

    # Count total tests across all test files
    total_tests = 0
    if isdir(tests_dir)
        for (root, dirs, files) in walkdir(tests_dir)
            for f in files
                if endswith(f, ".json")
                    full_path = joinpath(root, f)
                    try
                        data = JSON3.read(read(full_path, String))
                        if haskey(data, :tests)
                            total_tests += length(data[:tests])
                        end
                    catch
                        # Skip
                    end
                end
            end
        end
    end

    # Get Rubi source commit hash
    source_commit = ""
    try
        rubi_git_dir = joinpath(vendor_rubi_path, ".git")
        if isfile(rubi_git_dir) || isdir(rubi_git_dir)
            source_commit = strip(read(`git -C $vendor_rubi_path rev-parse HEAD`, String))
        end
    catch
        source_commit = "unknown"
    end

    # Update meta.json fields
    meta["rule_count"] = total_rules
    meta["test_count"] = total_tests
    meta["converter"] = Dict{String,Any}(
        "tool" => "RubiConverter.jl",
        "version" => "0.1.0",
        "source_commit" => source_commit,
        "converted_at" => Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    )

    # Write updated meta.json
    open(meta_path, "w") do io
        JSON3.pretty(io, meta; allow_inf=false)
        println(io)
    end

    println("Updated $meta_path:")
    println("  load_order: $(length(order)) files (preserved)")
    println("  rule_count: $total_rules")
    println("  test_count: $total_tests")
    println("  converter.source_commit: $(source_commit[1:min(8, length(source_commit))])...")
end
