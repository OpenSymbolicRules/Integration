using Test
include("../scripts/recover-profile.jl")
@testset "Recovery retains source and isolates unsupported rules" begin
    source = "(* header *)(* ::Code:: *)Int[x_,x_Symbol] := x^2/2\n(* ::Code:: *)Int[u_,x_Symbol] := 2 \\[Star] Int[u,x]\n(* ::Code:: *)Int[broken["
    rows = recover_profile(source, Set(["Int","Power","Divide","Multiply"]))
    @test join(getindex.(rows,"source"), "") == source
    @test [r["status"] for r in rows] == ["header","converted","candidate","source_only"]
    derivative = recover_profile("(* ::Code:: *)Int[Derivative[n_][f_][x_],x_Symbol] := Derivative[n-1][f][x] /; FreeQ[{f,n},x]", Set(["Int"]))[2]
    @test derivative["source_ast"]["head"] == "SetDelayed"
    @test derivative["source_ast"]["args"][2]["head"] == "Condition"
    @test rows[2]["rule"]["id"] == 1
    @test rows[3]["rule"]["id"] == 2
    @test recover_profile("Int[x_, x_Symbol] := x\n", Set(["Int"]))[1]["status"] == "converted"
    conditional = "(* ::Code:: *)If[TrueQ[\$LoadShowSteps], Int[u_,x_Symbol] := ShowStep[u] /; SimplifyFlag && SumQ[u], Int[u_,x_Symbol] := IntSum[u,x] /; SumQ[u]]"
    guarded = recover_profile(conditional, Set(["Int","SumQ"]))[2]
    @test guarded["status"] == "conditional"
    @test guarded["branches"]["false"]["result"] == ["IntSum","u","x"]
    @test guarded["branches"]["false"]["constraints"] == [["SumQ","u"]]
    @test recover_profile("(* ::Code:: *)If[test, a, b]", Set(["Int"]))[2]["status"] == "source_only"
end
