using RubiConverter, Test, JSON3

@testset "Read complete active fixture tuples and preserve source evidence" begin
    source = raw"""
    (* outside (* {1, x, 0, x} *)
    {2, x, 1, 2*x}
    *)
    {x!, x, If[$VersionNumber<9, 12, 20],
     f[x], g[x], h[x]}
    """
    mktempdir() do d
        p = joinpath(d, "1 Source.m")
        write(p, source)
        r = RubiConverter.convert_test_file(p; output_dir=d)
        @test isempty(r.warnings)
        @test r.test_count == 1
        row = only(JSON3.read(read(r.output_path, String)).tests)
        @test row.expression == ["Factorial", "x"]
        @test row.num_steps == 20
        for invalid in ("{x,x,1,x} extra", "(* unterminated", "{x,x,steps,x}", "{x,2,1,x}",
                        "{x,x,1,x}\n{bad", "{x!!,x,1,x}", "{x,x}", "{x,x,If[c,1,2],x}")
            write(p, invalid)
            @test !isempty(RubiConverter.convert_test_file(p; output_dir=d).warnings)
        end
    end
end
