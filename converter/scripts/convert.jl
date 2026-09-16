#!/usr/bin/env julia
# CLI entry point for the Mathematica-to-OSR converter
# Usage:
#   julia --project=converter converter/scripts/convert.jl --rules
#   julia --project=converter converter/scripts/convert.jl --tests
#   julia --project=converter converter/scripts/convert.jl --manifest
#   julia --project=converter converter/scripts/convert.jl [file.m]
#   julia --project=converter converter/scripts/convert.jl [file.m] --stdout

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using RubiConverter

const VERSION = "0.1.0"
const REPO_ROOT = abspath(joinpath(@__DIR__, "..", ".."))
const VENDOR_RUBI = joinpath(REPO_ROOT, "vendor", "Rubi")
const VENDOR_TESTS = joinpath(REPO_ROOT, "vendor", "MathematicaSyntaxTestSuite")

function print_usage()
    println("RubiConverter v$VERSION — Mathematica-to-OSR converter")
    println()
    println("DISCLAIMER: This is a community conversion tool and is not an official")
    println("product of the RUBI project or its author Albert Rich.")
    println()
    println("Usage:")
    println("  julia --project=converter converter/scripts/convert.jl --rules    Convert all RUBI rules")
    println("  julia --project=converter converter/scripts/convert.jl --tests    Convert all test problems")
    println("  julia --project=converter converter/scripts/convert.jl --manifest Update meta.json manifest")
    println("  julia --project=converter converter/scripts/convert.jl <file.m>   Convert a single .m file")
end

function main(args)
    if isempty(args) || "--help" in args || "-h" in args
        print_usage()
        return
    end

    if "--rules" in args
        println("Converting RUBI rules...")
        if !isdir(VENDOR_RUBI)
            println("ERROR: Rubi submodule not found at $VENDOR_RUBI")
            println("Run: git submodule update --init")
            exit(1)
        end
        results = RubiConverter.convert_all_rules(VENDOR_RUBI;
            output_dir=joinpath(REPO_ROOT, "rules"))
        return
    end

    if "--tests" in args
        println("Converting RUBI test suite...")
        if !isdir(VENDOR_TESTS)
            println("ERROR: MathematicaSyntaxTestSuite submodule not found at $VENDOR_TESTS")
            println("Run: git submodule update --init")
            exit(1)
        end
        results = RubiConverter.convert_all_tests(VENDOR_TESTS;
            output_dir=joinpath(REPO_ROOT, "tests"))
        return
    end

    if "--manifest" in args
        println("Updating meta.json manifest...")
        RubiConverter.update_manifest(
            joinpath(REPO_ROOT, "rules", "meta.json"),
            joinpath(REPO_ROOT, "rules"),
            joinpath(REPO_ROOT, "tests"),
            VENDOR_RUBI
        )
        return
    end

    # Single file mode
    file_path = args[1]
    if !isfile(file_path)
        println("ERROR: File not found: $file_path")
        exit(1)
    end

    result = RubiConverter.convert_rule_file(file_path;
        output_dir=joinpath(REPO_ROOT, "rules"))
    println("Converted $(result.rule_count) rules → $(result.output_path)")
    if !isempty(result.warnings)
        for w in result.warnings
            println("  WARNING: $(w.message)")
        end
    end
end

main(ARGS)
