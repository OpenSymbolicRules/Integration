using Test

@testset "Complete multiline rule expressions" begin
    source = """
    (* nested comments (* with misleading Int[x_,x_] := bad *) are ignored *)
    (* ::Code:: *)
    Int[(a_. + b_.*x_)^m_, x_Symbol] :=
      (a + b*x)^(m + 1)/(b*(m + 1)) /;
      FreeQ[{a, b, m}, x] && NeQ[m, -1]

    (* ::Code:: *)
    Int[x_, x_Symbol] :=
      x^2/2
    """
    expressions = RubiConverter.parse_file_expressions(source)
    rules = filter(x -> x isa RubiConverter.MFunction && x.head == "SetDelayed", expressions)
    @test length(rules) == 2
    @test rules[1].args[1].head == "Int"
    @test rules[1].args[2].head == "Condition"
    @test rules[2].args[1].head == "Int"

    # A malformed rule must not disappear silently.
    @test_throws RubiConverter.ParserError RubiConverter.parse_file_expressions(
        "(* ::Code:: *)\nInt[x_, x_Symbol] :=\n  Sin[\n")

    star = RubiConverter.parse_mathematica(raw"a \[Star] Int[f,x]")
    @test star isa RubiConverter.MFunction
    @test star.head == "Star"

    local_binding = RubiConverter.parse_mathematica("With[{k=Denominator[m]}, k*x]")
    @test local_binding.head == "With"
    @test local_binding.args[1].head == "List"
    @test local_binding.args[1].args[1].head == "Set"
end

@testset "RUBI source version is not guessed" begin
    mktempdir() do dir
        rubi = joinpath(dir, "Rubi")
        mkpath(joinpath(rubi, "IntegrationRules", "sample"))
        write(joinpath(rubi, "PacletInfo.m"), "Paclet[Version -> \"4.17.3.0\"]")
        source = joinpath(rubi, "IntegrationRules", "sample", "rule.m")
        @test RubiConverter.rubi_source_version(source) == "4.17.3.0"
        @test RubiConverter.rubi_source_version(joinpath(dir, "unknown.m")) === nothing
        p = RubiConverter.rubi_provenance("sample/rule.m", 1; version="4.17.3.0")
        @test p["sources"][1]["version"] == "4.17.3.0"
    end
end

@testset "Fail closed on unsupported RUBI Star semantics" begin
    mktempdir() do dir
        source = joinpath(dir, "1.1.2.1 sample.m")
        write(source, raw"""
        (* ::Code:: *)
        Int[x_,x_Symbol] :=
          2 \[Star] Int[x,x]
        """)
        result = RubiConverter.convert_rule_file(source; output_dir=joinpath(dir, "out"))
        @test result.rule_count == 0
        @test any(w -> occursin("Star", w.message), result.warnings)
        @test !isfile(result.output_path)

        vendor = joinpath(dir, "vendor", "Rubi", "IntegrationRules")
        mkpath(vendor)
        write(joinpath(vendor, "a-safe.m"), "(* ::Code:: *)\nInt[x_,x_Symbol] := x^2/2\n")
        cp(source, joinpath(vendor, "z-unsafe.m"))
        @test_throws ErrorException RubiConverter.convert_all_rules(joinpath(dir, "vendor");
            output_dir=joinpath(dir, "batch"))
        @test !isdir(joinpath(dir, "batch"))
    end
end

@testset "Convert a complete multiline file without Star" begin
    mktempdir() do dir
        source = joinpath(dir, "normalization.m")
        write(source, """
        (* ::Code:: *)
        Int[x_,x_Symbol] :=
          x^2/2

        (* ::Code:: *)
        Int[a_.*x_,x_Symbol] :=
          a*x^2/2 /;
        FreeQ[a,x]
        """)
        result = RubiConverter.convert_rule_file(source; output_dir=joinpath(dir, "out"))
        @test result.rule_count == 2
        @test isempty(result.warnings)
        @test isfile(result.output_path)
    end
end

@testset "Unreviewed local bindings do not enter the corpus" begin
    mktempdir() do dir
        source = joinpath(dir, "local.m")
        write(source, "(* ::Code:: *)\nInt[x_,x_Symbol] := With[{k=2},k*x]\n")
        result = RubiConverter.convert_rule_file(source; output_dir=joinpath(dir, "out"))
        @test result.rule_count == 0
        @test any(w -> occursin("Local binding", w.message), result.warnings)
        @test !isfile(result.output_path)
    end
end

@testset "Preserve RUBI Star and With in a candidate expression" begin
    source = raw"Int[x_,x_Symbol] := With[{k=2}, k \[Star] Int[x,x]]"
    rule = RubiConverter.rule_to_osr(RubiConverter.parse_mathematica(source), 1)
    @test rule["result"] == ["With", ["List", ["Set", "k", 2]],
        ["Star", "k", ["Int", "x", "x"]]]
    semantics = RubiConverter.rule_semantics([rule])
    @test semantics["Star"] == "openmath:arith1#times"
    @test semantics["Int"] == "openmath:calculus1#int"
    @test !haskey(semantics, "With")
    @test !haskey(semantics, "Set")

    mktempdir() do dir
        source_path = joinpath(dir, "candidate.m")
        write(source_path, "(* ::Code:: *)\n" * source)
        result = RubiConverter.convert_rule_file(source_path; output_dir=joinpath(dir, "out"),
            experimental_rubi_extensions=true)
        @test result.rule_count == 1
        @test isempty(result.warnings)
        doc = RubiConverter.JSON3.read(read(result.output_path, String))
        @test doc["rules"][1]["result"][1] == "With"
        @test doc["semantics"]["Star"] == "openmath:arith1#times"
    end
end

@testset "Experimental conversion rejects malformed scope" begin
    mktempdir() do dir
        source_path = joinpath(dir, "bad.m")
        write(source_path, "(* ::Code:: *)\nInt[x_,x_Symbol] := With[{k=1,k=2},k*x]\n")
        result = RubiConverter.convert_rule_file(source_path; output_dir=joinpath(dir, "out"),
            experimental_rubi_extensions=true)
        @test result.rule_count == 0
        @test !isempty(result.warnings)
        @test !isfile(result.output_path)
    end
end

@testset "Pinned RUBI 1.4.2 normalization file" begin
    source = joinpath(@__DIR__, "..", "..", "vendor", "Rubi", "Rubi",
        "IntegrationRules", "1 Algebraic functions", "1.4 Miscellaneous",
        "1.4.2 Algebraic function normalization.m")
    if isfile(source)
        mktempdir() do dir
            result = RubiConverter.convert_rule_file(source; output_dir=dir)
            @test result.rule_count == 29
            @test isempty(result.warnings)
            @test isfile(result.output_path)
        end
    else
        @test_skip isfile(source) # A checkout without the RUBI submodule.
    end
end

@testset "Pinned RUBI quadratic file preserves Star" begin
    source = joinpath(@__DIR__, "..", "..", "vendor", "Rubi", "Rubi",
        "IntegrationRules", "1 Algebraic functions", "1.1 Binomial products",
        "1.1.2 Quadratic", "1.1.2.1 (a+b x^2)^p.m")
    if isfile(source)
        mktempdir() do dir
            result = RubiConverter.convert_rule_file(source; output_dir=dir,
                experimental_rubi_extensions=true)
            @test result.rule_count == 33
            @test isempty(result.warnings)
            doc = RubiConverter.JSON3.read(read(result.output_path, String))
            @test doc["semantics"]["Star"] == "openmath:arith1#times"
            @test all(r -> r["provenance"]["sources"][1]["version"] == "4.17.3.0", doc["rules"])
        end
    else
        @test_skip isfile(source)
    end
end

@testset "Audit identifies parsed and unsupported cells independently" begin
    source = raw"""
    (* ::Code:: *)
    Int[x_,x_Symbol] := x^2/2
    (* ::Code:: *)
    Int[x_,x_Symbol] := 2 \[Star] Int[x,x]
    (* ::Code:: *)
    Int[x_,x_Symbol] := With[{k=2},k*x]
    (* ::Code:: *)
    Int[x_,x_Symbol] := Sin[
    """
    audit = RubiConverter.audit_code_cells(source)
    @test audit.candidates == 4
    @test audit.parsed == 3
    @test audit.star == 1
    @test audit.local_scope == 1
    @test length(audit.failures) == 1
    @test audit.failures[1].ordinal == 4
end
