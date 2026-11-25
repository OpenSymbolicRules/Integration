using Test
include("../scripts/source-edition.jl")
@testset "Source edition preserves order, guards and omitted positions" begin
    source = raw"""
    (* ::Code:: *) Int[x_,x_Symbol] := 2 \[Star] Int[x,x] /; NeQ[x,0]
    (* ::Code:: *) Int[u_,x_Symbol] := Module[{a},a=u]
    (* ::Code:: *) If[TrueQ[$LoadShowSteps],Int[u_,x_Symbol]:=ShowStep[IntSum[u,x]]/;SimplifyFlag&&SumQ[u],Int[u_,x_Symbol]:=IntSum[u,x]/;SumQ[u]]
    """
    rules, blocked = edition_rules(source, "example.m", "4.17.3.0")
    @test getindex.(rules,"id") == [1,3]
    @test first(rules)["result"][1] == "Star"
    @test first(rules)["constraints"] == [["NeQ","x",0]]
    @test last(rules)["constraints"] == [["SumQ","u"]]
    @test last(rules)["result"] == ["IntSum","u","x"]
    @test only(blocked).ordinal == 2
end

@testset "Operational requirements refer to RUBI definitions" begin
    refs = edition_extensions(Dict("IntSum"=>Set([2]), "Star"=>Set([2])), "IntSum[u_,x_] := foo", "pin")
    @test any(e -> e["name"] == "IntSum" && e["arity"] == 2 &&
        occursin("IntegrationUtilityFunctions.m",e["semantics"]),refs)
end

@testset "Plain show-steps branch preserves dynamic bindings and local assignments" begin
    wrap(rhs) = raw"If[TrueQ[$LoadShowSteps],Int[u_,x_Symbol]:=ShowStep[u],Int[u_,x_Symbol]:=" * rhs * "]"
    scoped = raw"With[{w=Block[{$ShowSteps=False,$StepCounter=Null},Int[u,x]]},Module[{v=u,d},d=v;Dist[d,w,x]]/;CalculusFreeQ[w,x]]/;InverseFunctionFreeQ[u,x]"
    rules, omitted = edition_rules(wrap(scoped), "example.m", "4.17.3.0")
    @test isempty(omitted)
    if !isempty(rules)
        r = only(rules)
        @test r["constraints"] == [["InverseFunctionFreeQ","u","x"]]
        @test r["result"] == ["With",["List",["Set","w",["Block",
            ["List",["Set",raw"$ShowSteps","False"],["Set",raw"$StepCounter","Null"]],
            ["Int","u","x"]]]],["Condition",["Module",["List",["Set","v","u"],"d"],
            ["CompoundExpression",["Set","d","v"],["Dist","d","w","x"]]],["CalculusFreeQ","w","x"]]]
    end
    for invalid in (replace(scoped, "d=v;"=>"outside=v;"), replace(scoped, raw"$ShowSteps=False"=>raw"$other=False"))
        @test isempty(first(edition_rules(wrap(invalid), "example.m", "4.17.3.0")))
    end
end

@testset "The two-coordinate angle extension declares its operand order" begin
    entry = only(edition_extensions(Dict("Atan2" => Set([2])), "", "pin"))
    @test entry["name"] == "Atan2" && entry["arity"] == 2
    @test occursin("horizontal", entry["semantics"])
    @test occursin("transc2#arctan", entry["semantics"])
    @test occursin("real", entry["semantics"]) && occursin("origin", entry["semantics"])
    @test occursin("complex", entry["semantics"])
end

@testset "Release first derivatives keep function and argument bindings" begin
    call(f, x) = ["Apply", f, ["List", x]]
    prime(f, x) = call(call(["Derivative", 1], f), x)
    source = "Int[h_'[z_]*j_[z_]+h_[z_]*j_'[z_],z_Symbol] := h[z]*j[z] /; FreeQ[{h,j},z]"
    convert(s) = edition_rules(s, "9 Miscellaneous/9.1 Derivative integration rules.m", "4.17.3.0"; release=true)
    rules, omitted = convert(source)
    @test isempty(omitted)
    r = only(rules)
    @test r["pattern"] == ["Int", ["Add",
        ["Multiply", prime("h_", "z_"), call("j_", "z_")],
        ["Multiply", call("h_", "z_"), prime("j_", "z_")]], "z_symbol"]
    @test r["result"] == ["Multiply", call("h", "z"), call("j", "z")]
    @test r["constraints"] == [["FreeQ", ["List", "h", "j"], "z"]]
    for invalid in (replace(source, "j_'[" => "j_''["),
                    replace(source, "j[z]" => "j[z,z]"),
                    replace(source, "h[z]*j[z]" => "With[{h=z},h[z]]"),
                    replace(source, "h_'[z_]" => "Derivative[n_][h_][z_]"))
        @test isempty(first(convert(invalid)))
    end
    @test isempty(first(edition_rules(source, "9 Miscellaneous/9.1 Derivative integration rules.m", "4.17.3.0")))
end

@testset "A positive integer guard permits the predecessor derivative" begin
    path = "9 Miscellaneous/9.1 Derivative integration rules.m"
    convert(s) = edition_rules(s, path, "4.17.3.0"; release=true)
    source = "Int[Derivative[k_][h_][z_],z_Symbol] := Derivative[k-1][h][z] /; FreeQ[h,z] && IGtQ[k,0]"
    rules, omitted = convert(source)
    @test isempty(omitted)
    r = only(rules)
    derivative(k, h, z) = ["Apply", ["Apply", ["Derivative", k], ["List", h]], ["List", z]]
    @test r["pattern"] == ["Int", derivative("k_", "h_", "z_"), "z_symbol"]
    @test r["result"] == derivative(["Add", "k", ["Multiply", -1, 1]], "h", "z")
    @test r["constraints"] == [["FreeQ", "h", "z"], ["IGtQ", "k", 0]]
    for invalid in (replace(source, "IGtQ[k,0]" => "ILtQ[k,0]"),
                    replace(source, "IGtQ[k,0]" => "IGtQ[r,0]"),
                    replace(source, "IGtQ[k,0]" => "(IGtQ[k,0] || ILtQ[k,0])"),
                    replace(source, "[k-1]" => "[k-2]"),
                    replace(source, "[h][z]" => "[other][z]"),
                    replace(source, "Derivative[k-1][h][z]" => "Int[Derivative[k-1][h][z],other]"))
        @test isempty(first(convert(invalid)))
    end
end

@testset "Source-qualified links to the real proofs" begin
    root = normpath(joinpath(@__DIR__, "../.."))
    edition = joinpath(root, "editions/rubi-4.17.3.0")
    family = "9-miscellaneous/9.1-Derivative-integration-rules.json"
    doc = JSON3.read(read(joinpath(edition, "rules", family), String))
    names = ["exponentialParts", "sineParts", "cosineParts", "product", "quotient", "logQuotient"]
    @test length(doc.rules) == length(names)
    for (rule, name) in zip(doc.rules, names)
        @test rule.references["Lean (real, under the stated hypotheses)"] == "OSR.Rubi." * name
        url = rule.references["Theorem statement"]
        pin, file, line = match(r"/blob/([0-9a-f]{40})/(verification/\w+\.lean)#L(\d+)$", url).captures
        @test occursin("theorem $name ", read(joinpath(root, file), String))
        # A full Git checkout can also verify the exact historical line anchor.
        if success(pipeline(`git -C $root cat-file -e $pin:$file`, stderr=devnull))
            source = read(`git -C $root show $pin:$file`, String)
            @test startswith(split(source, '\n')[parse(Int, line)], "theorem $name ")
        end
    end
    other = [Dict{String,Any}("id"=>19)]
    annotate_derivative_section!(other, [], repeat("0", 64))
    @test !haskey(only(other), "references")
end

@testset "Rubi 9.1 singular substitution coefficients" begin
    root = normpath(joinpath(@__DIR__, "../.."))
    ledger = JSON3.read(read(joinpath(root, "editions/rubi-4.17.3.0/coverage.json"), String))
    family = only(s for s in ledger.files if startswith(s.path, "9-miscellaneous/9.1-"))
    if !isempty(ARGS)
        vendor = only(ARGS)
        utility = read(`git -C $vendor show $(ledger.revision):Rubi/IntegrationUtilityFunctions.m`, String)
        compact = replace(utility, r"\s+" => "")
        @test occursin("FunctionOfQ[v_,u_,x_Symbol,PureFlag_:False]:=If[FreeQ[u,x],False,If[AtomQ[v],True,", compact)
    end
    cases = [o for o in family.omitted if o.ordinal in 16:18]
    @test getproperty.(cases, :ordinal) == [16, 17, 18]
    env = Dict("a"=>1, "b"=>1, "p"=>-1, "q"=>-1, "m"=>2, "n"=>2, "m1"=>1, "n1"=>1, "u"=>1, "x"=>1)
    # At x=1 the jets of f(t)=t² and g(t)=t³ give only finite positive values.
    jets = Dict("f"=>(1,2,2), "g"=>(1,3,6))
    function value(node)
        node isa MInteger && return node.value
        (node isa MPattern || node isa MSymbol) && return env[node.name]
        if node isa MApply
            order, fun = derivative_parts(node)
            @test value(only(node.args)) == 1
            return jets[fun.name][1 + value(order)]
        end
        if node.head in ("f_", "g_", "f", "g")
            @test value(only(node.args)) == 1
            return jets[rstrip(node.head, '_')][1]
        end
        args = map(value, node.args)
        node.head == "Plus" && return sum(args)
        node.head == "Times" && return prod(args)
        node.head == "Power" && return (args[1] // 1) ^ args[2]
        error("Unexpected witness expression: $(node.head)")
    end
    for (row, integrand) in zip(cases, (5, 4, 3))
        @test occursin("a/(p+1)", row.reason)
        expr = only(RubiConverter.parse_file_expressions(String(row.source)))
        parts = RubiConverter.extract_rule_parts(expr)
        @test value(parts.pattern) == integrand
        @test parts.result.head == "Star"
        @test RubiConverter.to_osr(first(parts.result.args)) ==
            ["Multiply", "a", ["Power", ["Add", "p", 1], -1]]
        for guard in parts.constraints
            if guard.head == "FreeQ"
                names, x = guard.args
                @test names.head == "List" && x.name == "x"
                @test all(s -> s.name in ("a","b","f","g","m","n","p","q"), names.args)
            elseif guard.head == "EqQ"
                left, right = guard.args
                @test value(left) == value(right)
            else
                # u is the expression x. The pinned FunctionOfQ first tests FreeQ[u,x]
                # (false), then AtomQ[v] (true for the constant substitution target 1).
                @test guard.head == "FunctionOfQ"
                target, u, x = guard.args
                @test (u.name, x.name) == ("u","x")
                @test target.head == "Times" && length(target.args) == 2
                @test all(t -> t.head == "Power" && value(t.args[2]) == 0 &&
                               value(t.args[1]) > 0, target.args)
                @test value(target) == 1
            end
        end
    end
end
