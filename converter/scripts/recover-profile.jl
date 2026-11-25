# Recover the initially empty sections of the pinned RUBI load profile.
using RubiConverter
using JSON3
using SHA

const CELL_MARKER = "(* ::Code:: *)"

function unknown_heads!(heads, node, allowed)
    node isa AbstractVector || return
    head = first(node)
    head in allowed || push!(heads, head)
    foreach(child -> unknown_heads!(heads, child, allowed), node[2:end])
end

function recover_profile(source, allowed; plain_steps=false)
    notebook = occursin(CELL_MARKER, source)
    blocks = notebook ? split(source, CELL_MARKER) : readlines(IOBuffer(source); keep=true)
    rows = Dict{String,Any}[]
    for (i, block) in enumerate(blocks)
        ordinal = notebook ? i-1 : i
        text = notebook && i > 1 ? CELL_MARKER * block : String(block)
        row = Dict{String,Any}("ordinal"=>ordinal, "source"=>text)
        push!(rows, row)
        expr = nothing
        try
            compound_arguments = plain_steps && startswith(lstrip(block), "If[")
            exprs = RubiConverter.parse_file_expressions(CELL_MARKER * String(block); compound_arguments)
            if isempty(exprs)
                row["status"] = ordinal == 0 ? "header" : "empty"
                continue
            end
            expr = only(exprs)
            if expr isa RubiConverter.MFunction && expr.head == "If"
                branches = Dict{String,Any}()
                for flag in (plain_steps ? (false,) : (true, false))
                    branch = RubiConverter.select_show_steps_branch(expr; show_steps=flag)
                    RubiConverter.validate_experimental_scope(branch; scoped_steps=plain_steps)
                    branches[string(flag)] = RubiConverter.rule_to_osr(branch, ordinal)
                end
                row["status"] = "conditional"
                row["branches"] = branches
                continue
            end
            expr isa RubiConverter.MFunction && expr.head == "SetDelayed" ||
                error("Expected an unconditional top-level definition")
            lhs = expr.args[1]
            lhs isa RubiConverter.MFunction && lhs.head == "Int" && length(lhs.args) == 2 ||
                error("Expected a binary Int pattern")
            RubiConverter.validate_experimental_scope(expr)
            rule = RubiConverter.rule_to_osr(expr, ordinal)
            row["rule"] = rule
            unknown = Set{String}()
            for term in (rule["pattern"], rule["result"], rule["constraints"]...)
                unknown_heads!(unknown, term, allowed)
            end
            row["status"] = isempty(unknown) ? "converted" : "candidate"
            isempty(unknown) || (row["required_heads"] = sort(collect(unknown)))
        catch err
            err isa InterruptException && rethrow()
            row["status"] = "source_only"
            row["reason"] = sprint(showerror, err)
            isnothing(expr) || (row["source_ast"] = RubiConverter.diagnostic_ast(expr))
        end
    end
    rows
end

function write_json(path, data)
    mkpath(dirname(path))
    open(path, "w") do io
        JSON3.pretty(io, data)
        println(io)
    end
end

function recover_files(root, vendor, output)
    meta = JSON3.read(read(joinpath(root, "rules/meta.json"), String))
    revision = String(meta.converter.source_commit)
    version = String(meta.rubi_version)
    allowed = union(keys(RubiConverter.OPENMATH_SEMANTICS), meta.predicates, meta.utility_functions,
                    ["List","And","Or","Not"])
    setdiff!(allowed, ["Star","With","Module","Set","If","UnknownHead"])
    for path in JSON3.read(read(joinpath(root, "converter/recovery/files.json"), String))
        doc = JSON3.read(read(joinpath(root, "rules", path), String), Dict{String,Any})
        source_path = String(doc["identity"])[6:end] * ".m"
        blob = "$revision:Rubi/IntegrationRules/$source_path"
        source = read(`git -C $vendor show $blob`, String)
        rows = recover_profile(source, allowed)
        rules = Dict{String,Any}[]
        for row in rows
            row["status"] == "converted" || continue
            rule = row["rule"]
            rule["provenance"] = RubiConverter.rubi_provenance(source_path, row["ordinal"]; version=version)
            push!(rules, rule)
        end
        doc["rules"] = rules
        doc["semantics"] = RubiConverter.rule_semantics(rules)
        write_json(joinpath(output, "rules", path), doc)
        archive = joinpath(output, "converter/recovery", path)
        mkpath(dirname(archive))
        open(archive, "w") do io
            # One block per line keeps large source sections reviewable.
            print(io, "{\"source_path\":", JSON3.write(source_path), ",\"revision\":",
                JSON3.write(revision), ",\"source_sha256\":",
                JSON3.write(bytes2hex(sha256(source))), ",\"blocks\":[\n")
            for (i, row) in enumerate(rows)
                println(io, JSON3.write(row), i == length(rows) ? "" : ",")
            end
            println(io, "]}")
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 2 || error("Usage: recover-profile.jl RUBI_GIT_DIR NEW_OUTPUT")
    ispath(ARGS[2]) && error("Output already exists")
    recover_files(normpath(joinpath(@__DIR__, "../..")), ARGS...)
end
