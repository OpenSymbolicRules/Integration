using Test
using RubiConverter

@testset "RubiConverter" begin

@testset "Tokenizer" begin
    @testset "basic arithmetic" begin
        tokens = RubiConverter.tokenize("a + b*x")
        kinds = [t.kind for t in tokens]
        @test kinds == [RubiConverter.TOK_SYMBOL, RubiConverter.TOK_PLUS,
                        RubiConverter.TOK_SYMBOL, RubiConverter.TOK_STAR,
                        RubiConverter.TOK_SYMBOL, RubiConverter.TOK_EOF]
    end

    @testset "pattern syntax" begin
        tokens = RubiConverter.tokenize("x_ a_. m_Integer")
        kinds = [t.kind for t in tokens]
        @test kinds == [RubiConverter.TOK_SYMBOL, RubiConverter.TOK_BLANK,
                        RubiConverter.TOK_SYMBOL, RubiConverter.TOK_BLANK,
                        RubiConverter.TOK_DOT,
                        RubiConverter.TOK_SYMBOL, RubiConverter.TOK_BLANK,
                        RubiConverter.TOK_SYMBOL,
                        RubiConverter.TOK_EOF]
    end

    @testset "condition and assignment" begin
        tokens = RubiConverter.tokenize("lhs := rhs /; cond")
        kinds = [t.kind for t in tokens]
        @test kinds == [RubiConverter.TOK_SYMBOL, RubiConverter.TOK_SETDELAYED,
                        RubiConverter.TOK_SYMBOL, RubiConverter.TOK_CONDITION,
                        RubiConverter.TOK_SYMBOL, RubiConverter.TOK_EOF]
    end

    @testset "comments are skipped" begin
        tokens = RubiConverter.tokenize("(* comment *) x + y")
        kinds = [t.kind for t in tokens[1:end-1]]  # exclude EOF
        @test kinds == [RubiConverter.TOK_SYMBOL, RubiConverter.TOK_PLUS,
                        RubiConverter.TOK_SYMBOL]
    end

    @testset "list syntax" begin
        tokens = RubiConverter.tokenize("{a, b, c}")
        kinds = [t.kind for t in tokens]
        @test kinds == [RubiConverter.TOK_LBRACE, RubiConverter.TOK_SYMBOL,
                        RubiConverter.TOK_COMMA, RubiConverter.TOK_SYMBOL,
                        RubiConverter.TOK_COMMA, RubiConverter.TOK_SYMBOL,
                        RubiConverter.TOK_RBRACE, RubiConverter.TOK_EOF]
    end

    @testset "logical operators" begin
        tokens = RubiConverter.tokenize("a && b || !c")
        kinds = [t.kind for t in tokens]
        @test kinds == [RubiConverter.TOK_SYMBOL, RubiConverter.TOK_AND,
                        RubiConverter.TOK_SYMBOL, RubiConverter.TOK_OR,
                        RubiConverter.TOK_NOT, RubiConverter.TOK_SYMBOL,
                        RubiConverter.TOK_EOF]
    end
end

@testset "Parser" begin
    @testset "simple arithmetic" begin
        expr = RubiConverter.parse_mathematica("a + b*x")
        @test expr isa RubiConverter.MFunction
        @test expr.head == "Plus"
        @test length(expr.args) == 2
    end

    @testset "power expression" begin
        expr = RubiConverter.parse_mathematica("(a + b*x)^m")
        @test expr isa RubiConverter.MFunction
        @test expr.head == "Power"
        @test expr.args[1] isa RubiConverter.MFunction
        @test expr.args[1].head == "Plus"
    end

    @testset "pattern variable" begin
        expr = RubiConverter.parse_mathematica("x_")
        @test expr isa RubiConverter.MPattern
        @test expr.name == "x"
        @test expr.blank_type == :blank
    end

    @testset "optional pattern" begin
        expr = RubiConverter.parse_mathematica("a_.")
        @test expr isa RubiConverter.MPattern
        @test expr.name == "a"
        @test expr.blank_type == :optional
    end

    @testset "typed pattern" begin
        expr = RubiConverter.parse_mathematica("m_Integer")
        @test expr isa RubiConverter.MPattern
        @test expr.name == "m"
        @test expr.blank_type == :blank
        @test expr.type_head == "Integer"
    end

    @testset "function application" begin
        expr = RubiConverter.parse_mathematica("FreeQ[{a, b}, x]")
        @test expr isa RubiConverter.MFunction
        @test expr.head == "FreeQ"
        @test length(expr.args) == 2
        @test expr.args[1] isa RubiConverter.MFunction
        @test expr.args[1].head == "List"
    end

    @testset "rule definition" begin
        src = "Int[(a_. + b_.*x_)^m_, x_Symbol] := (a + b*x)^(m + 1)/(b*(m + 1)) /; FreeQ[{a, b, m}, x] && NeQ[m, -1]"
        expr = RubiConverter.parse_mathematica(src)
        @test expr isa RubiConverter.MFunction
        @test expr.head == "SetDelayed"
        # LHS is Int[...]
        @test expr.args[1] isa RubiConverter.MFunction
        @test expr.args[1].head == "Int"
        # RHS is Condition[result, test]
        @test expr.args[2] isa RubiConverter.MFunction
        @test expr.args[2].head == "Condition"
    end

    @testset "list (test tuple)" begin
        expr = RubiConverter.parse_mathematica("{x^3, x, 1, x^4/4}")
        @test expr isa RubiConverter.MFunction
        @test expr.head == "List"
        @test length(expr.args) == 4
    end

    @testset "negative number" begin
        expr = RubiConverter.parse_mathematica("-3")
        @test expr isa RubiConverter.MInteger
        @test expr.value == -3
    end

    @testset "fraction" begin
        expr = RubiConverter.parse_mathematica("3/2")
        @test expr isa RubiConverter.MFunction
        @test expr.head == "Times"
    end
end

@testset "Operator mapping" begin
    @test RubiConverter.map_operator("Plus") == "Add"
    @test RubiConverter.map_operator("Times") == "Multiply"
    @test RubiConverter.map_operator("ArcSin") == "Asin"
    @test RubiConverter.map_operator("ArcCosh") == "Acosh"
    @test RubiConverter.map_operator("Int") == "Int"
    @test RubiConverter.map_operator("Simp") == "Simp"
    # Unknown operators pass through
    @test RubiConverter.map_operator("CustomFunc") == "CustomFunc"
end

@testset "Wildcard mapping" begin
    @test RubiConverter.map_wildcard("x", :blank, nothing) == "x_"
    @test RubiConverter.map_wildcard("a", :optional, nothing) == "a."
    @test RubiConverter.map_wildcard("m", :blank, "Integer") == "m_integer"
    @test RubiConverter.map_wildcard("x", :blank, "Symbol") == "x_"
    @test RubiConverter.map_wildcard("xs", :blankseq, nothing) == "xs__"
    @test RubiConverter.map_wildcard("xs", :blanknullseq, nothing) == "xs___"
end

@testset "Path utilities" begin
    @test RubiConverter.convert_dirname("1 Algebraic functions") == "1-algebraic"
    @test RubiConverter.convert_dirname("1.1 Binomial products") == "1.1-binomial"
    @test RubiConverter.convert_dirname("1.1.1 Linear") == "1.1.1-linear"
    @test RubiConverter.convert_filename("1.1.1.1 (a+b x)^m.m") == "1.1.1.1-(a+b-x)^m.json"

    @test RubiConverter.extract_section_number("1.1.1.1 (a+b x)^m.m") == "1.1.1.1"
    @test RubiConverter.extract_title("1.1.1.1 (a+b x)^m.m") == "(a+b x)^m"
end

@testset "Transformer — expression to OSR-Expr" begin
    @testset "simple addition" begin
        expr = RubiConverter.parse_mathematica("a + b")
        osr = RubiConverter.to_osr(expr)
        @test osr == Any["Add", "a", "b"]
    end

    @testset "power with pattern" begin
        expr = RubiConverter.parse_mathematica("(a_. + b_.*x_)^m_")
        osr = RubiConverter.to_osr(expr)
        @test osr[1] == "Power"
        @test osr[2][1] == "Add"
        @test "a." in osr[2]      # optional wildcard
        @test osr[3] == "m_"      # mandatory wildcard
    end

    @testset "function call" begin
        expr = RubiConverter.parse_mathematica("FreeQ[{a, b}, x]")
        osr = RubiConverter.to_osr(expr)
        @test osr[1] == "FreeQ"
        @test osr[2] == Any["List", "a", "b"]
        @test osr[3] == "x"
    end

    @testset "rule extraction" begin
        src = "Int[(a_. + b_.*x_)^m_, x_Symbol] := (a + b*x)^(m + 1)/(b*(m + 1)) /; FreeQ[{a, b, m}, x] && NeQ[m, -1]"
        expr = RubiConverter.parse_mathematica(src)
        parts = RubiConverter.extract_rule_parts(expr)
        @test parts.pattern isa RubiConverter.MFunction
        @test length(parts.constraints) == 2
        @test parts.result isa RubiConverter.MExpr
    end

    @testset "test tuple extraction" begin
        expr = RubiConverter.parse_mathematica("{x^3, x, 1, x^4/4}")
        entry = RubiConverter.test_tuple_to_osr(expr, 1)
        @test entry["id"] == 1
        @test entry["variable"] == "x"
        @test entry["num_steps"] == 1
        # `test-file.schema.json` names these fields `expression` and
        # `expected_result`.
        @test entry["expression"] == Any["Power", "x", 3]
        # Mathematica normalises `a/b` to `a * b^-1`, so the converter emits a
        # reciprocal power rather than a `Divide` node.
        @test entry["expected_result"] ==
              Any["Multiply", Any["Power", "x", 4], Any["Power", 4, -1]]
    end
end

@testset "Full pipeline — known rule" begin
    src = "Int[(a_. + b_.*x_)^m_, x_Symbol] := (a + b*x)^(m + 1)/(b*(m + 1)) /; FreeQ[{a, b, m}, x] && NeQ[m, -1]"
    expr = RubiConverter.parse_mathematica(src)
    rule = RubiConverter.rule_to_osr(expr, 1)

    @test rule["id"] == 1
    @test haskey(rule, "pattern")
    @test haskey(rule, "constraints")
    @test haskey(rule, "result")
    @test length(rule["constraints"]) == 2

    # First constraint should be FreeQ[{a, b, m}, x]
    c1 = rule["constraints"][1]
    @test c1[1] == "FreeQ"
end

end  # @testset "RubiConverter"
