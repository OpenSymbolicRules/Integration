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
