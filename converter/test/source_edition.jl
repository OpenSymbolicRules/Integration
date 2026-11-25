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
