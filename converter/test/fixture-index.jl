using RubiConverter, Test
include("../scripts/fixture-index.jl")

@testset "Source index retains extra fields, version branches and line spans" begin
    source = raw"""
    (* header *)
    {x, x, 0, x}
    {x!, x, If[$VersionNumber<9, 12, 20],
      f[x], g[x], h[x]}
    """
    mktempdir() do dir
        path = joinpath(dir, "1 Fixture.m")
        write(path, source)
        converted = RubiConverter.convert_test_file(path; output_dir=dir)
        row = fixture_source_record("1 Fixture.m", source, converted.output_path, "1-Fixture.json")
        @test row.source_lines == [2, [3,4]]
        @test length(row.details) == 1
        detail = only(row.details)
        @test detail["id"] == 2
        @test detail["source_steps"] == ["If", ["Less", raw"$VersionNumber", 9], 12, 20]
        @test detail["extra_fields"] == [["g", "x"], ["h", "x"]]
    end
end
