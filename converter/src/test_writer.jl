# Test file writer: convert a test .m file to OSR JSON

using JSON3

struct TestConversionResult
    output_path::String
    section::String
    title::String
    test_count::Int
    warnings::Vector{ConversionWarning}
end

# In 8.10 the legacy parser skipped every tuple containing postfix primes.
# These source ordinals already had IDs 1..36. New IDs follow those 36.
const FORMAL_DERIVATIVE_LEGACY_ORDINALS = [4, 5, 43:67..., 70, 73, 76, 80, 84, 88, 91, 94, 97]

const RETIRED_FIXTURE_FILE = joinpath(@__DIR__, "../data/retired-fixture-ids.json")
include_dependency(RETIRED_FIXTURE_FILE)
const RETIRED_FIXTURES = JSON3.read(read(RETIRED_FIXTURE_FILE, String), Dict{String,Vector{Vector{Int}}})

function fixture_ids(rel_path, count)
    if haskey(RETIRED_FIXTURES, rel_path)
        retired_ids = first.(RETIRED_FIXTURES[rel_path])
        ids = setdiff(1:(count + length(retired_ids)), retired_ids)
        length(ids) == count || error("Review retired fixture IDs for $rel_path")
        return ids
    end
    rel_path == "8 Special functions/8.10 Formal derivatives.m" || return 1:count
    count == 97 || error("Review the formal derivative fixture ID mapping for this source edition")
    ordinals = 1:count
    sortperm(vcat(FORMAL_DERIVATIVE_LEGACY_ORDINALS, setdiff(ordinals, FORMAL_DERIVATIVE_LEGACY_ORDINALS)))
end

# Read one complete outer list at a time. The tokenizer tracks nested comments
# and line numbers across the whole file, including multiline tuples.
function active_fixture_tuples(source)
    parser = Parser(tokenize(source); postfix_factorial=true)
    rows = NamedTuple{(:line, :last_line, :tuple),Tuple{Int,Int,MFunction}}[]
    while !at(parser, TOK_EOF)
        start = current(parser)
        at(parser, TOK_LBRACE) || throw(ParserError("Expected a fixture tuple", start.line, start.col))
        tuple = parse_atom(parser)
        length(tuple.args) >= 4 || throw(ParserError("Expected at least four fixture fields", start.line, start.col))
        last_line = parser.tokens[parser.pos - 1].line
        if !at(parser, TOK_EOF) && current(parser).line == last_line
            throw(ParserError("Trailing tokens after fixture tuple", last_line, current(parser).col))
        end
        push!(rows, (; line=start.line, last_line, tuple))
    end
    rows
end

# JSON3.pretty reparses numbers while formatting. Write the original scalars
# directly so arbitrarily large integer literals never pass through Float64.
function write_fixture_json(io, value, depth=0)
    if !(value isa AbstractDict || value isa AbstractVector)
        JSON3.write(io, value; allow_inf=false)
        return
    end
    object = value isa AbstractDict
    print(io, object ? "{\n" : "[\n")
    indent = "    " ^ depth
    for (i, (key, child)) in enumerate(pairs(value))
        i > 1 && print(io, ",\n")
        print(io, indent, "    ")
        if object
            JSON3.write(io, key)
            print(io, ": ")
        end
        write_fixture_json(io, child, depth + 1)
    end
    isempty(value) || println(io)
    print(io, indent, object ? "}" : "]")
end

"""
    convert_test_file(source_path::String; output_dir::String="tests") -> TestConversionResult

Convert a single Mathematica test .m file to a OSR JSON test file.
Extracts {integrand, variable, num_steps, antiderivative} tuples.
"""
function convert_test_file(source_path::String; output_dir::String="tests")::TestConversionResult
    source = read(source_path, String)
    section = extract_section_number(source_path)
    title = extract_title(source_path)

    # Compute relative path from the test suite directory
    rel_path = replace(source_path, '\\' => '/')
    for base in ["MathematicaSyntaxTestSuite/", "0 Independent test suites/"]
        idx = findfirst(base, rel_path)
        if idx !== nothing
            rel_path = rel_path[nextind(rel_path, last(idx)):end]
            break
        end
    end

    output_path = mathematica_path_to_osr(rel_path; prefix=output_dir)

    warnings = ConversionWarning[]
    tests = Dict{String,Any}[]

    # Parse all expressions from the file
    rows = try
        active_fixture_tuples(source)
    catch e
        push!(warnings, ConversionWarning(source_path, 0, "Failed to parse file: $e", ""))
        return TestConversionResult(output_path, section, title, 0, warnings)
    end

    for (id, row) in zip(fixture_ids(rel_path, length(rows)), rows)
        try
            push!(tests, test_tuple_to_osr(row.tuple, id))
        catch e
            push!(warnings, ConversionWarning(source_path, row.line, "Failed to convert test $id: $e", ""))
        end
    end

    # Build the OSR test file JSON
    osr_file = Dict{String,Any}(
        "\$schema" => "open-symbolic-rules/v0.1",
        "section" => section,
        "title" => title,
        "tests" => tests,
    )

    # Write output
    mkpath(dirname(output_path))
    open(output_path, "w") do io
        write_fixture_json(io, osr_file)
        println(io)  # trailing newline
    end

    TestConversionResult(output_path, section, title, length(tests), warnings)
end

"""
    convert_all_tests(vendor_path::String; output_dir::String="tests") -> Vector{TestConversionResult}

Convert all test .m files from the MathematicaSyntaxTestSuite vendor submodule to OSR JSON.
"""
function convert_all_tests(vendor_path::String; output_dir::String="tests")::Vector{TestConversionResult}
    # Find all .m files, sorted
    m_files = String[]
    for (root, dirs, files) in walkdir(vendor_path)
        for f in files
            if endswith(f, ".m")
                push!(m_files, joinpath(root, f))
            end
        end
    end
    sort!(m_files)

    isempty(m_files) && error("No fixture sources found in $vendor_path")
    parent = dirname(abspath(output_dir))
    mkpath(parent)
    mktempdir(parent) do staging
        results = TestConversionResult[]
        for (i, m_file) in enumerate(m_files)
            print("  [$i/$(length(m_files))] $(relpath(m_file, vendor_path))")
            result = convert_test_file(m_file; output_dir=staging)
            println(" → $(result.test_count) tests")
            for warning in result.warnings
                println(stderr, "  WARNING $(warning.file): $(warning.message)")
            end
            push!(results, result)
        end

        total_tests = sum(r.test_count for r in results)
        total_warnings = sum(length(r.warnings) for r in results)
        println("\nSummary: $total_tests tests converted from $(length(results)) files ($total_warnings warnings)")
        iszero(total_warnings) || error("Incomplete fixture conversion: $total_warnings warnings")
        allunique(r.output_path for r in results) || error("Duplicate fixture output path")

        published = TestConversionResult[]
        for r in results
            target = joinpath(output_dir, relpath(r.output_path, staging))
            mkpath(dirname(target))
            mv(r.output_path, target; force=true)
            push!(published, TestConversionResult(target, r.section, r.title, r.test_count, r.warnings))
        end
        published
    end
end
