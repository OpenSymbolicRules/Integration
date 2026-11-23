#!/usr/bin/env julia
# Read-only audit of notebook cells. JSON goes to stdout; no rules are written.
using RubiConverter
using JSON3

length(ARGS) == 1 || error("Usage: julia --project=converter converter/scripts/audit-cells.jl VENDOR_RUBI")
vendor = abspath(ARGS[1])
root = joinpath(vendor, "Rubi", "IntegrationRules")
isdir(root) || error("IntegrationRules directory not found: $root")
paths = sort([joinpath(dir, file) for (dir, _, files) in walkdir(root)
              for file in files if endswith(file, ".m")])
results = []
for path in paths
    source = read(path, String)
    occursin("(* ::Code:: *)", source) || continue
    audit = RubiConverter.audit_code_cells(source)
    push!(results, (; path=relpath(path, root), audit...))
end
revision = try
    strip(read(pipeline(`git -C $vendor rev-parse HEAD`; stderr=devnull), String))
catch
    nothing
end
version = RubiConverter.rubi_source_version(joinpath(root, "source.m"))
report = (; source_version=version, source_revision=revision,
    notebook_files=length(results),
    candidates=sum(x.candidates for x in results; init=0),
    parsed=sum(x.parsed for x in results; init=0),
    star=sum(x.star for x in results; init=0),
    local_scope=sum(x.local_scope for x in results; init=0),
    failures=sum(length(x.failures) for x in results; init=0),
    files=results)
JSON3.pretty(stdout, report)
println()
