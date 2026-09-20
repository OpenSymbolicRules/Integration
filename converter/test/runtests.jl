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
    # `Symbol` is a restriction like any other type head, not noise to drop:
    # see "A Symbol-typed pattern variable keeps its type" below.
    @test RubiConverter.map_wildcard("x", :blank, "Symbol") == "x_symbol"
    @test RubiConverter.map_wildcard("xs", :blankseq, nothing) == "xs__"
    @test RubiConverter.map_wildcard("xs", :blanknullseq, nothing) == "xs___"
end

@testset "Path utilities" begin
    @test RubiConverter.convert_dirname("1 Algebraic functions") == "1-algebraic"
    @test RubiConverter.convert_dirname("1.1 Binomial products") == "1.1-binomial"
    @test RubiConverter.convert_dirname("1.1.1 Linear") == "1.1.1-linear"
    @test RubiConverter.convert_filename("1.1.1.1 (a+b x)^m.m") == "1.1.1.1-(a+b-x)^m.json"

    @test RubiConverter.extract_section_number("1.1.1.1 (a+b x)^m.m") == "1.1.1.1"
    # RUBI also uses alphabetic leaf identifiers.  Keeping the complete source
    # identifier prevents distinct files such as 1.1.2.x and 1.1.2.y from
    # generating the same OSR `section:id` rule identity.
    @test RubiConverter.extract_section_number("1.1.2.x P(x) (a+b x^2)^p.m") == "1.1.2.x"
    @test RubiConverter.extract_section_number("7.1.4a (f x)^m.m") == "7.1.4a"
    @test RubiConverter.source_identity("1 Algebraic functions/1.1 Binomial products/1.1.2 Quadratic/1.1.2.x P(x) (a+b x^2)^p.m") ==
          "rubi:1 Algebraic functions/1.1 Binomial products/1.1.2 Quadratic/1.1.2.x P(x) (a+b x^2)^p"
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

@testset "A rule keeps its integration variable" begin
    src = "Int[(a_. + b_.*x_)^m_, x_Symbol] := (a + b*x)^(m + 1)/(b*(m + 1)) /; FreeQ[{a, b, m}, x] && NeQ[m, -1]"
    rule = RubiConverter.rule_to_osr(RubiConverter.parse_mathematica(src), 1)

    # RUBI writes an integration rule as Int[integrand, x_Symbol]. Keeping only
    # the integrand loses the binding of the integration variable, so the
    # result and the constraints name an `x` nothing bound, and loses the
    # restriction that made the rule sound: without it the pattern matches an
    # integrand that is not a function of any variable at all.
    @test rule["pattern"][1] == "Int"
    @test length(rule["pattern"]) == 3
    @test rule["pattern"][3] == "x_symbol"

    # The integrand is what it used to be, now one level down.
    integrand = rule["pattern"][2]
    @test integrand[1] == "Power"

    # `x` is now bound by the pattern, so the result and the guard refer to a
    # binding rather than to a free symbol.
    @test "Int" in keys(RubiConverter.rule_semantics([rule]))
end

@testset "A Symbol-typed pattern variable keeps its type" begin
    @test RubiConverter.map_wildcard("x", :blank, "Symbol") == "x_symbol"
    @test RubiConverter.map_wildcard("x", :blank, nothing) == "x_"
    @test RubiConverter.map_wildcard("m", :blank, "Integer") == "m_integer"
    @test RubiConverter.map_wildcard("a", :optional, nothing) == "a."
end

@testset "Rule semantics cover constraint expressions" begin
    # A constraint applies predicates to mathematical expressions, and those
    # expressions carry domain vocabulary just as a pattern or a result does.
    # Collecting heads from the pattern and the result alone leaves a utility
    # such as `Coeff` or `Expon` undeclared, which a loader then rejects.
    rules = [Dict(
        "id" => 1,
        "pattern" => ["Int", ["Power", "x", "m."], "x"],
        "result" => ["Divide", ["Power", "x", ["Add", "m", 1]], ["Add", "m", 1]],
        "constraints" => Any[
            ["NeQ", ["Coeff", ["Multiply", "a", "x"], "x", 1], 0],
            ["Not", ["IGtQ", ["Expon", "Px", "x"], 1]],
        ],
    )]
    semantics = RubiConverter.rule_semantics(rules)

    # Operators reached through a constraint are declared.
    @test semantics["Coeff"] == "openmath:osr#Coeff"
    @test semantics["Expon"] == "openmath:osr#Expon"
    @test semantics["Multiply"] == "openmath:arith1#times"

    # A predicate name is rule-language vocabulary, not a mathematical
    # operator, so it gets no OpenMath binding.
    @test !haskey(semantics, "NeQ")
    @test !haskey(semantics, "IGtQ")
    @test !haskey(semantics, "Not")

    # A structural head of the expression language needs none either.
    with_list = [Dict(
        "id" => 1,
        "pattern" => ["Power", "x", "m."],
        "result" => "m.",
        "constraints" => Any[["FreeQ", ["List", "a", "b"], "x"]],
    )]
    @test !haskey(RubiConverter.rule_semantics(with_list), "List")

    # `Condition` guards a pattern with a test: the pattern is an expression,
    # the test is a constraint.
    guarded = [Dict(
        "id" => 1,
        "pattern" => ["Power", "x", "m."],
        "result" => "m.",
        "constraints" => Any[["MatchQ", "Px",
            ["Condition", ["Divide", "a", "x"], ["FreeQ", ["Coeff", "a", "x"], "x"]]]],
    )]
    guarded_semantics = RubiConverter.rule_semantics(guarded)
    @test guarded_semantics["Divide"] == "openmath:arith1#divide"
    @test guarded_semantics["Coeff"] == "openmath:osr#Coeff"
    @test !haskey(guarded_semantics, "Condition")
    @test !haskey(guarded_semantics, "MatchQ")
    @test !haskey(guarded_semantics, "FreeQ")

    # A wildcard in operator position names a binding, not an operation.
    head_wildcard = [Dict(
        "id" => 1,
        "pattern" => ["trig_", ["Add", "e", "x"]],
        "result" => "x",
        "constraints" => Any[],
    )]
    @test !haskey(RubiConverter.rule_semantics(head_wildcard), "trig_")
end

@testset "Rule provenance" begin
    provenance = RubiConverter.rubi_provenance(
        "1 Algebraic functions/1.1 Binomial products/example.m", 7
    )
    @test provenance["method"] == "converted"
    @test provenance["sources"][1]["name"] == "Rubi"
    @test provenance["sources"][1]["locator"] ==
          "1 Algebraic functions/1.1 Binomial products/example.m#7"
end

end  # @testset "RubiConverter"
