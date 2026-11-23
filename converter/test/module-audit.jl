include(joinpath(@__DIR__, "..", "scripts", "audit-module.jl"))

@testset "Module audit distinguishes declarations and assignments" begin
    parsed = RubiConverter.parse_mathematica("Module[{q=f[x],k},g[k]]")
    assignment = RubiConverter.MFunction("Set", [RubiConverter.MSymbol("k"), RubiConverter.MSymbol("q")])
    body = RubiConverter.MFunction("CompoundExpression", [assignment, parsed.args[2]])
    expr = RubiConverter.MFunction("Module", [parsed.args[1], body])
    audit = audit_modules([expr])
    @test audit["modules"] == 1
    @test audit["initialized_locals"] == 1
    @test audit["uninitialized_locals"] == 1
    @test audit["body_assignments"] == 1
    @test audit["compound_bodies"] == 1
    malformed = RubiConverter.parse_mathematica("Module[x,f[x]]")
    @test audit_modules([malformed])["unsupported_declarations"] == 1
    @test audit_modules([RubiConverter.parse_mathematica("f[x]")])["modules"] == 0
    @test audit_modules([RubiConverter.parse_mathematica("f[x][Module[{k},k]]")])["modules"] == 1
end
