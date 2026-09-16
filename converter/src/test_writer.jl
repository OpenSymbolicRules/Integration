# Test file writer: convert a test .m file to OSR JSON

using JSON3

struct TestConversionResult
    output_path::String
    section::String
    title::String
    test_count::Int
    warnings::Vector{ConversionWarning}
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
    rel_path = source_path
    for base in ["MathematicaSyntaxTestSuite/", "0 Independent test suites/"]
        idx = findfirst(base, source_path)
        if idx !== nothing
            rel_path = source_path[idx.start + length(base):end]
            break
        end
    end

    output_path = mathematica_path_to_osr(rel_path; prefix=output_dir)

    warnings = ConversionWarning[]
    tests = Dict{String,Any}[]

    # Parse all expressions from the file
    expressions = try
        parse_file_expressions(source)
    catch e
        push!(warnings, ConversionWarning(source_path, 0, "Failed to parse file: $e", ""))
        return TestConversionResult(output_path, section, title, 0, warnings)
    end

    # Extract test tuples (List with 4 elements)
    test_id = 0
    for expr in expressions
        if expr isa MFunction && expr.head == "List" && length(expr.args) >= 4
            test_id += 1
            try
                test_entry = test_tuple_to_osr(expr, test_id)
                push!(tests, test_entry)
            catch e
                push!(warnings, ConversionWarning(
                    source_path, 0,
                    "Failed to convert test $test_id: $e",
                    ""
                ))
            end
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
        JSON3.pretty(io, osr_file; allow_inf=false)
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

    results = TestConversionResult[]
    for (i, m_file) in enumerate(m_files)
        rel = replace(m_file, vendor_path * "/" => "")
        print("  [$i/$(length(m_files))] $rel")
        result = convert_test_file(m_file; output_dir=output_dir)
        println(" → $(result.test_count) tests" *
                (isempty(result.warnings) ? "" : " ($(length(result.warnings)) warnings)"))
        push!(results, result)
    end

    total_tests = sum(r.test_count for r in results)
    total_warnings = sum(length(r.warnings) for r in results)
    println("\nSummary: $total_tests tests converted from $(length(results)) files ($total_warnings warnings)")

    results
end
