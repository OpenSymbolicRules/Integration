# Reproduce the correspondence between pinned source tuples and distributed fixtures.
using JSON3, SHA, RubiConverter

function fixture_source_record(path, source, json_path, json_file)
    rows = RubiConverter.active_fixture_tuples(source)
    cases = JSON3.read(read(json_path, String)).tests
    ids = RubiConverter.fixture_ids(path, length(rows))
    [case.id for case in cases] == ids || error("Fixture ID mismatch: $json_file")
    lines = Any[]
    details = Dict{String,Any}[]
    for (row, case) in zip(rows, cases)
        push!(lines, row.line == row.last_line ? row.line : [row.line, row.last_line])
        fields = row.tuple.args
        case.num_steps == RubiConverter.resolve_num_steps(fields[3]) || error("Step mismatch: $path:$(row.line)")
        item = Dict{String,Any}("id" => case.id)
        if !(fields[3] isa RubiConverter.MInteger)
            item["source_steps"] = RubiConverter.fixture_expr(fields[3])
        end
        if length(fields) > 4
            item["extra_fields"] = map(RubiConverter.fixture_expr, fields[5:end])
        end
        length(item) > 1 && push!(details, item)
    end
    (; source_file=path, source_sha256=bytes2hex(sha256(source)), json_file,
       json_sha256=open(bytes2hex ∘ sha256, json_path), source_lines=lines, details)
end

function converter_identity(root)
    directory = joinpath(root, "converter")
    inputs = ["Project.toml", "Manifest.toml", "data/retired-fixture-ids.json",
              "scripts/convert.jl", "scripts/fixture-index.jl"]
    append!(inputs, [joinpath("src", f) for f in readdir(joinpath(directory, "src")) if endswith(f, ".jl")])
    files = [(; path="converter/" * p, sha256=open(bytes2hex ∘ sha256, joinpath(directory, p)))
             for p in sort(inputs)]
    (; name="RubiConverter", repository="https://github.com/OpenSymbolicRules/Integration",
       version=string(pkgversion(RubiConverter)), files)
end

function fixture_index(vendor, fixtures, destination)
    root = normpath(joinpath(@__DIR__, "../.."))
    revision = strip(read(`git -C $root rev-parse HEAD:vendor/MathematicaSyntaxTestSuite`, String))
    paths = split(read(`git -C $vendor ls-tree -rz --name-only $revision`, String), '\0'; keepempty=false)
    filter!(p -> endswith(p, ".m"), paths)
    isempty(paths) && error("No fixture sources at $revision")
    mkpath(dirname(abspath(destination)))
    mktemp(dirname(abspath(destination))) do tmp, io
        header = (; format_version=1, source_repository="https://github.com/RuleBasedIntegration/MathematicaSyntaxTestSuite",
                  source_revision=revision, source_license_file="LICENSE", converter=converter_identity(root),
                  wolfram_language_version=RubiConverter.FIXTURE_LANGUAGE_VERSION,
                  retired_ids="converter/data/retired-fixture-ids.json")
        print(io, chop(JSON3.write(header)), ",\"files\":[\n")
        for (i, path) in enumerate(paths)
            source = read(`git -C $vendor show $revision:$path`, String)
            json_file = RubiConverter.mathematica_path_to_osr(String(path); prefix="tests")
            json_path = joinpath(fixtures, relpath(json_file, "tests"))
            record = fixture_source_record(String(path), source, json_path, json_file)
            JSON3.write(io, record)
            println(io, i == length(paths) ? "" : ",")
        end
        println(io, "]}")
        close(io)
        mv(tmp, destination; force=true)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 3 || error("Usage: fixture-index.jl RUBI_TEST_GIT_DIR OSR_TEST_DIR OUTPUT_JSON")
    fixture_index(ARGS...)
end
