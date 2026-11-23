using JSON3

@testset "Manifest preserves reviewed load order" begin
    mktempdir() do root
        rules = joinpath(root, "rules")
        tests = joinpath(root, "tests")
        mkpath(rules)
        mkpath(tests)
        write(joinpath(rules, "a.json"), "{\"rules\":[{},{}]}")
        write(joinpath(rules, "b.json"), "{\"rules\":[{}]}")
        write(joinpath(rules, "excluded.json"), "{\"rules\":[{}]}")
        meta = joinpath(rules, "meta.json")
        write(meta, "{\"load_order\":[\"b.json\",\"a.json\"]}")
        RubiConverter.update_manifest(meta, rules, tests, root)
        updated = JSON3.read(read(meta, String))
        @test updated.load_order == ["b.json", "a.json"]
        @test updated.rule_count == 4

        for order in (["missing.json"], ["a.json", "a.json"])
            original = JSON3.write(Dict("load_order" => order))
            write(meta, original)
            @test_throws Exception RubiConverter.update_manifest(meta, rules, tests, root)
            @test read(meta, String) == original
        end
    end
end
