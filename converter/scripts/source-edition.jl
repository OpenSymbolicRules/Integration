# Generate a standalone v0.1 corpus directly from the pinned RUBI loader inputs.
include("recover-profile.jl")

function edition_rules(source, path, version)
    rules = Dict{String,Any}[]
    omitted = NamedTuple[]
    for row in recover_profile(source, Set{String}(); plain_steps=true)
        status = row["status"]
        if status in ("empty", "header")
            continue
        elseif status == "source_only"
            push!(omitted, (; ordinal=row["ordinal"], reason=row["reason"], source=row["source"]))
            continue
        end
        rule = status == "conditional" ? row["branches"]["false"] : row["rule"]
        rule["provenance"] = RubiConverter.rubi_provenance(path, row["ordinal"]; version)
        push!(rules, rule)
    end
    rules, omitted
end

function collect_arities!(arities, term)
    term isa AbstractVector || return
    push!(get!(Set{Int}, arities, first(term)), length(term)-1)
    foreach(child -> collect_arities!(arities,child), term[2:end])
end

function edition_extensions(arities, utility_source, revision)
    # These newly exposed heads have their definitions in the pinned RUBI utility file.
    helpers = Set(split("""Denom DerivativeDivides EulerIntegrandQ ExpandExpression
        FractionalPowerFactorQ FreeFactors FunctionOfExponential FunctionOfExponentialFunction
        FunctionOfLinear FunctionOfLog FunctionOfSquareRootOfQuadratic FunctionOfTrig InertTrigFreeQ
        IntSum InverseFunctionOfLinear MonomialQ NonfreeFactors NonsumQ Numer PiecewiseLinearQ
        PolynomialInQ PolynomialInSubst QuotientOfLinearsParts RationalFunctionExponents
        SimplerIntegrandQ SplitProduct SubstForFractionalPowerQ SubstPower TryPureTanSubst"""))
    wolfram = Set(["Block","CompoundExpression","Discriminant","FunctionExpand","GCD","GreaterEqual","Module","Root","Set"])
    result = Dict{String,Any}[]
    for name in sort(collect(keys(arities)))
        semantics = if name == "Star"
            "RUBI Star[u,v] in Rubi/IntegrationUtilityFunctions.m at $revision. Preserve its distribution and evaluation behavior. Decline the rule if unsupported (OSR-X-025a)."
        elseif name == "Atan2"
            "Wolfram ArcTan[x,y], with horizontal coordinate x and vertical coordinate y. The reviewed OpenMath interpretation (openmath:transc2#arctan) is the principal angle for real coordinates away from the origin. For complex or unknown coordinates preserve the source call unless the host supports the Wolfram branch convention."
        elseif name in helpers
            occursin(Regex("(?m)^" * name * raw"\[.*\][ \t]*(?::=|=(?!=))"), utility_source) ||
                error("Missing pinned RUBI definition for $name")
            "Implement the $name definitions in Rubi/IntegrationUtilityFunctions.m at $revision, with step display disabled. Decline the rule if unsupported."
        elseif name in wolfram
            "Wolfram Language built-in as used in the source: https://reference.wolfram.com/language/ref/$name.html. Decline the rule if unsupported."
        else
            continue
        end
        ns = sort(collect(arities[name]))
        push!(result,Dict("name"=>name, "arity"=>length(ns)==1 ? only(ns) : join(ns, ", "), "semantics"=>semantics))
    end
    result
end

function generate_edition(root, vendor, output; edition=nothing)
    reference = joinpath(root, "rules")
    meta = JSON3.read(read(joinpath(reference, "meta.json"), String), Dict{String,Any})
    if !isnothing(edition)
        meta["load_order"] = edition["load_order"]
        meta["rubi_version"] = edition["version"]
        meta["converter"]["source_commit"] = edition["revision"]
    end
    revision = meta["converter"]["source_commit"]
    version = meta["rubi_version"]
    ledger = []
    arities = Dict{String,Set{Int}}()
    count = 0
    for path in meta["load_order"]
        doc = JSON3.read(read(joinpath(reference, path), String), Dict{String,Any})
        source_path = doc["identity"][6:end] * ".m"
        blob = "$revision:Rubi/IntegrationRules/$source_path"
        source = read(`git -C $vendor show $blob`, String)
        rules, omitted = edition_rules(source, source_path, version)
        if !isnothing(edition)
            for rule in rules
                only(rule["provenance"]["sources"])["revision"] = revision
            end
        end
        doc["identity"] = "rubi@$revision:" * source_path
        for rule in rules, term in (rule["pattern"], rule["result"], rule["constraints"]...)
            collect_arities!(arities, term)
        end
        doc["rules"] = rules
        doc["semantics"] = RubiConverter.rule_semantics(rules)
        dest = joinpath(output, "rules", path)
        mkpath(dirname(dest))
        open(dest,"w") do io
            # Keep individual rules reviewable in source order.
            header = Dict(k=>v for (k,v) in doc if k != "rules")
            print(io, chop(JSON3.write(header)), ",\"rules\":[\n")
            for (i,r) in enumerate(rules)
                println(io, JSON3.write(r), i == length(rules) ? "" : ",")
            end
            println(io, "]}")
        end
        push!(ledger,(; path, source_path, sha256=bytes2hex(sha256(source)),
                      converted=length(rules), omitted))
        count += length(rules)
    end
    meta["title"] = "RUBI integration rules in pinned source order"
    meta["description"] = "Elementary rules enabled, step display disabled. Apply a rule only when the host implements its pattern, operators, scopes and predicates."
    meta["rule_count"] = count
    delete!(meta, "test_count")
    meta["feature_flags"]["load_show_steps"] = false
    helpers = read(`git -C $vendor show $revision:Rubi/IntegrationUtilityFunctions.m`, String)
    meta["extensions"] = edition_extensions(arities, helpers, revision)
    delete!(meta["converter"], "converted_at")
    write_json(joinpath(output,"rules/meta.json"),meta)
    write_json(joinpath(output,"coverage.json"),(;revision,version,files=ledger))
    println("$count rules in $(length(ledger)) files")
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) in (2, 3) || error("Usage: source-edition.jl RUBI_GIT_DIR NEW_DIRECTORY [EDITION_JSON]")
    ispath(ARGS[2]) && error("Output already exists")
    generate_edition(normpath(joinpath(@__DIR__,"../..")), ARGS[1], ARGS[2];
        edition=length(ARGS) == 3 ? JSON3.read(read(ARGS[3], String), Dict{String,Any}) : nothing)
end
