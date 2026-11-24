include(joinpath(@__DIR__, "..", "scripts", "recover-cells.jl"))

@testset "Cell recovery preserves order, gaps and selected load branch" begin
    source = raw"""
    (* ::Code:: *) Int[x_,x_Symbol] := x
    (* ::Code:: *) Int[x_,x_Symbol] := Module[{a},a=x]
    (* ::Code:: *) If[TrueQ[$LoadShowSteps],Int[u_,x_Symbol]:=ShowStep[IntSum[u,x]]/;SimplifyFlag&&SumQ[u],Int[u_,x_Symbol]:=IntSum[u,x]/;SumQ[u]]
    (* ::Code:: *) Int[x_,x_Symbol] := With[{k=2},k*x]
    """
    report = recover_cells(source; show_steps=false)
    @test [row["cell"] for row in report] == [1, 2, 3, 4]
    @test [row["status"] for row in report] == ["candidate", "blocked", "candidate", "candidate"]
    @test report[2]["source_ast"]["head"] == "SetDelayed"
    @test report[2]["source_ast"]["args"][2]["head"] == "Module"
    @test report[3]["rule"]["result"] == ["IntSum", "u", "x"]
    @test report[3]["rule"]["constraints"] == [["SumQ", "u"]]
    @test report[3]["selected_show_steps"] == false
    @test report[4]["rule"]["id"] == 4
    @test report[4]["syntax_features_detected"] == ["With"]
    @test_throws ArgumentError recover_cells("Int[x_,x_Symbol] := x"; show_steps=false)
    @test recover_cells("(* ::Code:: *) Int[x_,x_Symbol] := Sin["; show_steps=false)[1]["status"] == "blocked"
    @test recover_cells("(* ::Code:: *) (* no rule *)"; show_steps=false)[1]["status"] == "empty"
    @test recover_cells(raw"(* ::Code:: *) If[TrueQ[$Wrong],Int[u_,x_Symbol]:=u,Int[u_,x_Symbol]:=u]"; show_steps=false)[1]["status"] == "blocked"
end

@testset "Pinned 1.4.1 branch recovery remains diagnostic" begin
    source = joinpath(@__DIR__, "..", "..", "vendor", "Rubi", "Rubi",
        "IntegrationRules", "1 Algebraic functions", "1.4 Miscellaneous",
        "1.4.1 Algebraic function simplification.m")
    if isfile(source)
        report = recover_cells(read(source, String); show_steps=false)
        @test count(r -> r["status"] == "candidate", report) == 68
        @test count(r -> r["status"] == "empty", report) == 11
        @test count(r -> r["status"] == "blocked", report) == 1
        @test report[9]["selected_show_steps"] == false
        @test report[9]["rule"]["result"] == ["IntSum", "u", "x"]
        @test report[9]["rule"]["constraints"] == [["SumQ", "u"]]
        @test report[29]["status"] == "blocked"
        @test occursin("scope", report[29]["reason"])
    else
        @test_skip isfile(source)
    end
end
