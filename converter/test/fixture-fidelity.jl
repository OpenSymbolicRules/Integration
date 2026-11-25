using Test
using RubiConverter
using JSON3

@testset "Fixture conversion preserves applied heads, exact literals and published IDs" begin
    mktempdir() do dir
        src = joinpath(dir, "1 Fixture.m")
        huge = "123456789012345678901234567890123456789"
        write(src, """
        {f''[g[x]], x, 1, Derivative[2][f][g[x]]}
        {Derivative[n-1][F][x], x, 2, Defer[Subst][F[x], x, y]}
        {$huge*x, x, 1, -$huge}
        {unreviewed[a][x], x, 0, x}
        """)
        out = RubiConverter.convert_test_file(src; output_dir=joinpath(dir, "out"))
        @test out.test_count == 3
        @test length(out.warnings) == 1
        raw = read(out.output_path, String)
        @test length(findall(huge, raw)) == 2
        rows = JSON3.read(raw, Dict{String,Any})["tests"]
        @test rows[1]["expression"] == rows[1]["expected_result"] ==
            ["Apply", ["Apply", ["Derivative", 2], ["List", "f"]], ["List", ["g", "x"]]]
        @test rows[2]["expression"][2][2] == ["Derivative", ["Add", "n", ["Multiply", -1, 1]]]
        @test rows[2]["expected_result"] ==
            ["Apply", ["Defer", "Subst"], ["List", ["F", "x"], "x", "y"]]
    end

    source = joinpath(@__DIR__, "../../vendor/MathematicaSyntaxTestSuite/8 Special functions/8.10 Formal derivatives.m")
    if isfile(source)
        mktempdir() do dir
            report = RubiConverter.convert_test_file(source; output_dir=dir)
            @test isempty(report.warnings)
            cases = JSON3.read(read(report.output_path, String)).tests
            @test length(cases) == 97
            @test sort([c.id for c in cases]) == 1:97
            @test [cases[i].id for i in (1, 2, 3, 4, 5, 43, 97)] == [37, 38, 39, 1, 2, 3, 36]
        end
    end
end

@testset "A fixture batch with a rejected case preserves existing outputs" begin
    mktempdir() do dir
        vendor = joinpath(dir, "MathematicaSyntaxTestSuite")
        output = joinpath(dir, "tests")
        mkpath(vendor)
        write(joinpath(vendor, "1 First.m"), "{x, x, 1, x^2/2}")
        published = only(RubiConverter.convert_all_tests(vendor; output_dir=output)).output_path
        original = read(published)
        write(joinpath(vendor, "1 First.m"), "{1, x, 1, x}")
        write(joinpath(vendor, "2 Invalid.m"), "{bad[a][x], x, 1, x}")
        @test_throws ErrorException RubiConverter.convert_all_tests(vendor; output_dir=output)
        @test read(published) == original
    end
end

@testset "Unary and binary ArcTan preserve their meanings in the same rule and fixture" begin
    src = "Int[ArcTan[x_],x_Symbol]:=ArcTan[0,x]+ArcTan[x,0]/;NeQ[ArcTan[x],0]"
    rule = RubiConverter.rule_to_osr(RubiConverter.parse_mathematica(src), 1)
    @test rule["pattern"] == ["Int", ["Atan", "x_"], "x_symbol"]
    @test rule["constraints"] == [["NeQ", ["Atan", "x"], 0]]
    @test rule["result"] == ["Add", ["Atan2", 0, "x"], ["Atan2", "x", 0]]
    semantics = RubiConverter.rule_semantics([rule])
    @test semantics["Atan"] == "openmath:transc1#arctan"
    @test get(semantics, "Atan2", nothing) == "openmath:transc2#arctan"

    tuple = RubiConverter.parse_mathematica("{ArcTan[ArcTan[t],s], x, 2, ArcTan[s,t]}")
    case = RubiConverter.test_tuple_to_osr(tuple, 7)
    @test case["expression"] == ["Atan2", ["Atan", "t"], "s"]
    @test case["expected_result"] == ["Atan2", "s", "t"]
    for invalid in ("ArcTan[]", "ArcTan[a,b,c]", "Atan2[x,y]")
        @test_throws ArgumentError RubiConverter.to_osr(RubiConverter.parse_mathematica(invalid))
    end
end
