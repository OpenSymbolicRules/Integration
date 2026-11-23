include(joinpath(@__DIR__, "..", "scripts", "recover-empty.jl"))

@testset "Experimental recovery is isolated and reports failures" begin
    mktempdir() do root
        rules = joinpath(root, "rules")
        vendor = joinpath(root, "vendor")
        source = joinpath(vendor, "Rubi", "IntegrationRules", "section")
        mkpath(rules)
        mkpath(source)
        write(joinpath(rules, "meta.json"), JSON3.write(Dict("load_order" => ["empty.json", "missing.json"])))
        write(joinpath(rules, "empty.json"), JSON3.write(Dict("identity" => "rubi:section/example", "rules" => [])))
        write(joinpath(rules, "missing.json"), JSON3.write(Dict("identity" => "rubi:section/missing", "rules" => [])))
        write(joinpath(source, "example.m"), raw"(* ::Code:: *) Int[x_,x_Symbol] := 2 \[Star] Int[x,x]" *
              "\n(* ::Code:: *) Int[x_,x_Symbol] := With[{k=2},k*x]")
        output = joinpath(root, "candidate")
        report = recover_empty_rules(rules, vendor, output)
        @test report["candidate_files"] == 1
        @test report["candidate_rules"] == 2
        @test report["files"][1]["syntax_features_detected"] == ["Star", "With"]
        @test report["files"][1]["rules_with_star"] == 1
        @test report["files"][1]["rules_with_with"] == 1
        @test report["files"][1]["rule_ids_with_star"] == [1]
        @test report["files"][1]["rule_ids_with_with"] == [2]
        @test report["blocked_files"] == 1
        @test JSON3.read(read(joinpath(rules, "empty.json"), String))["rules"] == []
        @test isfile(joinpath(output, "report.json"))
        @test_throws Exception recover_empty_rules(rules, vendor, output)
        @test_throws Exception recover_empty_rules(rules, vendor, rules)
    end
end
