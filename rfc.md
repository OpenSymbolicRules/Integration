# RFC: Language-Neutral JSON Format for RUBI Rules and Test Fixtures (OSR v0.1)

**Category:** Ideas / RFC  
**Labels:** `rubi-5`, `interoperability`, `json`, `specification`, `json-schema`

---

## TL;DR

I'm proposing **OSR** (Open Symbolic Rules) — a JSON format with validated JSON Schema to represent **all** of RUBI's ~7,800 integration rules and 72,000+ test problems independently of Mathematica. The v0.1 spec covers the complete operator catalogue (29 special functions including Bessel, ~55 utility functions, 65+ predicates including the `FunctionOf*` family), matches RUBI's actual 9-section taxonomy exactly, and preserves the semantically critical rule loading order.

This discussion is a request for feedback before finalizing.

---

## The Problem

Today, RUBI rules exist only in Mathematica-native formats (`.nb`, `.m`). Every port — SymJa (Java), SymPy (Python), Julia, etc. — reparses those files with ad-hoc converters. This means:

1. **Duplicated effort.** Each port team writes and maintains their own Mathematica parser.
2. **Drift.** Ports fall behind RUBI upstream because conversion is manual and fragile.
3. **No shared test fixture.** Each port defines its own test subset. There is no single, authoritative, language-neutral test suite that all implementations can validate against.
4. **Barrier to entry.** Anyone wanting to build a RUBI engine in Rust, JavaScript, or any other language must first solve the Mathematica parsing problem.

## The Proposal

Define a **JSON interchange format** with **validatable JSON Schema** that captures:

- **Rules**: pattern + constraints + result, with full wildcard and predicate support
- **Test fixtures**: integrand + variable + optimal antiderivative + expected step count
- **Taxonomy**: RUBI's exact 9-section hierarchy (algebraic → exponentials → logarithms → trig → inverse trig → hyperbolic → inverse hyperbolic → special → miscellaneous)
- **Load manifest**: the precise file loading order that determines rule priority

The JSON files become the **single source of truth** that any CAS can consume with a standard JSON parser — no Mathematica required.

---

## Design Overview

### Expression Language (OSR-Expr)

Mathematical expressions use a simple S-expression-in-JSON encoding:

```json
["Add", ["Multiply", "a_", ["Power", "x_", "n_"]], "b_"]
```

This represents `a·xⁿ + b`, where `a_`, `x_`, `n_`, `b_` are wildcards.

**Operator names** follow PascalCase and align with [MathLive MathJSON](https://cortexjs.io/math-json/) conventions for de facto compatibility: `Add`, `Sin`, `Power`, `Exp`, `Log`, etc.

**Key divergence from MathJSON:** Inverse trig/hyp functions are first-class operators (`Asin`, `Acos`, `Atan`, `Asinh`, etc.) rather than compositional `["Apply", ["InverseFunction", "Sin"], x]`. This matches how RUBI rules reference `ArcSin[x]` as an atomic head, and simplifies pattern matching.

### Wildcards

| Syntax | Meaning | Example |
|--------|---------|---------|
| `x_` | Mandatory wildcard (must bind) | `"n_"` matches any sub-expression |
| `a.` | Optional wildcard (default 0) | `"a."` matches or defaults to 0 |
| `m.3` | Optional with explicit default | `"m.3"` matches or defaults to 3 |
| `m_integer` | Typed wildcard | `"m_integer"` matches only integers |
| `xs__` | Sequence (1+ args) | BlankSequence — matches one or more sub-expressions |
| `xs___` | Sequence (0+ args) | BlankNullSequence — matches zero or more sub-expressions |

> Default convention without explicit specifier: additive-role names (`a.`, `b.`, `c.`…) default to 0; multiplicative-role names (`m.`, `n.`, `p.`…) default to 1. This matches RUBI's most common `Optional` usage.

### Rule Structure

```json
{
  "$schema": "rubi-integration-rules/v0.1",
  "section": "1.1.1",
  "title": "(a+b x)^m",
  "rules": [
    {
      "id": 1,
      "pattern": ["Power", ["Add", "a.", ["Multiply", "b.", "x_"]], "m."],
      "constraints": [
        ["FreeQ", ["List", "a.", "b.", "m."], "x_"]
      ],
      "result": ["Simp",
        ["Divide",
          ["Power", ["Add", "a.", ["Multiply", "b.", "x_"]], ["Add", "m.", 1]],
          ["Multiply", "b.", ["Add", "m.", 1]]
        ],
        "x_"
      ],
      "description": "∫(a+b·x)^m dx → (a+b·x)^(m+1) / (b·(m+1))",
      "derivation": "Power rule for linear binomials",
      "references": { "CRC": "1" }
    }
  ]
}
```

**Rule priority is determined by file loading order** (defined in `meta.json`'s `load_order` manifest), then by position within each file. The `id` field is for traceability and step display only — not a priority key.

> This matches RUBI's `Rubi.m`, which states: *"The order of loading the rule-files below is crucial to ensure a functional Rubi integrator!"*

### Test Fixture Structure

```json
{
  "$schema": "rubi-integration-rules/v0.1",
  "section": "1.1.1",
  "title": "Linear binomial test problems",
  "tests": [
    {
      "id": 1,
      "integrand": ["Power", ["Add", 1, ["Multiply", 2, "x"]], 3],
      "variable": "x",
      "optimal_antiderivative": ["Divide",
        ["Power", ["Add", 1, ["Multiply", 2, "x"]], 4], 8],
      "num_steps": 1
    }
  ]
}
```

Results are compared by **symbolic equivalence**, not syntactic equality. Grading follows the RUBI scale: A (≤2× optimal size), B (correct but >2×), C (correct, sub-optimal), F (incorrect/timeout).

---

## JSON Schema

The format is defined by **4 JSON Schema files** (draft-07), all validated:

| Schema | Purpose |
|--------|---------|
| `osr-expr.schema.json` | Shared recursive expression type + operator/predicate enum catalogues (17 definitions) |
| `rule-file.schema.json` | Rule files: `$schema`, `section`, `title`, `rules[]` with `id`, `pattern`, `constraints`, `result` |
| `meta.schema.json` | Root manifest: `load_order`, `feature_flags`, `taxonomy`, `predicates[]`, `utility_functions[]`, `extensions[]` |
| `test-file.schema.json` | Test fixtures: `integrand`, `variable`, `optimal_antiderivative`, `num_steps` |

### meta.json — The Load Manifest

The `meta.json` file is the root of a OSR rule set. Its most important field is `load_order` — an ordered array that defines exactly which files to load and in what sequence:

```json
{
  "$schema": "rubi-integration-rules/v0.1",
  "osr_version": "0.1.0",
  "rubi_version": "4.16.1",
  "license": "MIT",
  "rule_count": 7800,

  "feature_flags": {
    "load_elementary_function_rules": true,
    "load_bessel_functions": false
  },

  "load_order": [
    "1-algebraic/1.1-binomial/1.1.1-linear/1.1.1.1-(a+b-x)^m.json",
    "1-algebraic/1.1-binomial/1.1.1-linear/1.1.1.2-(a+b-x)^m-(c+d-x)^n.json",
    "...",
    "3-logarithms/3.1-u-(a+b-log(c-x^n))^p.json",
    "...",
    "4-trig/4.1-sine/4.1.1.1-(a+b-sin)^n.json",
    "...",
    { "path": "8-special/8.10-bessel.json", "requires": "load_bessel_functions" },
    "...",
    "9-miscellaneous/9.4-miscellaneous-integration.json"
  ],

  "taxonomy": [
    { "section": 1, "title": "Algebraic functions" },
    { "section": 2, "title": "Exponentials" },
    { "section": 3, "title": "Logarithms" },
    { "section": 4, "title": "Trig functions" },
    { "section": 5, "title": "Inverse trig functions" },
    { "section": 6, "title": "Hyperbolic functions" },
    { "section": 7, "title": "Inverse hyperbolic functions" },
    { "section": 8, "title": "Special functions" },
    { "section": 9, "title": "Miscellaneous" }
  ],

  "predicates": ["FreeQ", "IGtQ", "...65+ predicates..."],
  "utility_functions": ["NormalizeIntegrand", "Rt", "ActivateTrig", "...55 functions..."],
  "extensions": [],
  "custom_predicates": []
}
```

Key features:
- **`load_order`** defines exact file sequence (rule priority). Entries can be strings or `{"path": "...", "requires": "flag"}` for conditional loading.
- **`feature_flags`** mirror RUBI's `$LoadElementaryFunctionRules` / `$LoadShowSteps` flags.
- **`#`-prefixed entries** are commented out (disabled), matching RUBI's `(*LoadRules[...]*)`  convention.
- **Orphan files** (present on disk but not in `load_order`) are not loaded.

---

## Full Operator Catalogue

The v0.1 catalogue was built by auditing RUBI's actual repository: `IntegrationUtilityFunctions.m`, the IntegrationRules PDF directory structure, the `Rubi.m` load sequence, and the SymPy port's `utility_function.py`.

### Mathematical functions (99 operators)

| Category | Count | Operators |
|----------|-------|-----------|
| **Core arithmetic** | 9 | `Add`, `Subtract`, `Multiply`, `Divide`, `Power`, `Negate`, `Sqrt`, `Abs`, `Factorial` |
| **Trig** | 6 | `Sin`, `Cos`, `Tan`, `Cot`, `Sec`, `Csc` |
| **Hyperbolic** | 6 | `Sinh`, `Cosh`, `Tanh`, `Coth`, `Sech`, `Csch` |
| **Inverse trig** | 6 | `Asin`, `Acos`, `Atan`, `Acot`, `Asec`, `Acsc` |
| **Inverse hyperbolic** | 6 | `Asinh`, `Acosh`, `Atanh`, `Acoth`, `Asech`, `Acsch` |
| **Exp/Log** | 2 | `Exp`, `Log` |
| **Special functions** | 29 | Previous 25 + `BesselJ`, `BesselY`, `BesselI`, `BesselK` |
| **Constants** | 7 | `Pi`, `E`, `I`, `Infinity`, `ComplexInfinity`, `GoldenRatio`, `EulerGamma` |
| **Structural** | 28 | Previous 18 + `Module`, `Head`, `Length`, `Part`, `Apply`, `Scan`, `Catch`, `Throw`, `Hold`, `HoldForm` |

### Integration-specific operators (7)

`Int`, `Dist`, `Subst`, `Simp`, `ExpandIntegrand`, `Unintegrable`, `CannotIntegrate`

### Utility functions (~55 — algorithmic, implemented by each Phrasebook)

Organized in 6 subcategories:

| Category | Functions |
|----------|-----------|
| **Normalization / simplification** | `NormalizeIntegrand`, `SimplifyIntegrand`, `SimplifyAntiderivative`, `NormalizeLeadTermSigns`, `NormalizeSumFactors`, `AbsorbMinusSign`, `FixSimplify`, `SmartSimplify`, `TogetherSimplify`, `ContentFactor` |
| **Polynomial / algebraic** | `Coefficient`, `Exponent`, `IntPart`, `FracPart`, `Together`, `Apart`, `Cancel`, `Factor`, `Expand`, `Numerator`, `Denominator`, `SmartNumerator`, `SmartDenominator`, `Rt` |
| **Trig manipulation** | `TrigReduce`, `TrigExpand`, `TrigToExp`, `ExpToTrig`, `SmartTrigExpand`, `SmartTrigReduce`, `TrigSimplifyAux`, **`ActivateTrig`**, **`DeactivateTrig`** |
| **Structural decomposition** | `LeadTerm`, `RemainingTerms`, `LeadFactor`, `RemainingFactors`, `LeadBase`, `LeadDegree`, `MergeFactor`, `MergeFactors` |
| **Substitution helpers** | `SubstFor`, `SubstForFractionalPowerOfLinear`, `SubstForFractionalPowerOfQuotientOfLinears`, `SubstForInverseFunction`, `SubstForExpn` |
| **Calculus / general** | `D`, **`Dif`**, `Map`, `Simplify`, `FullSimplify`, `ReplaceAll`, `Mods` |

> **`ActivateTrig` / `DeactivateTrig`** implement RUBI's inert trig function mechanism — trig functions are temporarily deactivated during pattern matching to prevent premature CAS evaluation (`Sin[x]^2 + Cos[x]^2` → `1`), then reactivated in final results. RUBI sections 4.7.5 and 4.7.9 contain these rules.
>
> **`Dif`** is RUBI's own symbolic derivative, distinct from Mathematica's built-in `D`, used to avoid side effects during rule application.
>
> **`Rt`** is RUBI's n-th root that chooses the simplest real or complex form.

### Predicates (65+ — used in rule constraints)

| Category | Predicates |
|----------|-----------|
| **Independence** | `FreeQ`, `IndependentQ` |
| **Type tests** | `IntegerQ`, `PositiveIntegerQ`, `NegativeIntegerQ`, `FractionQ`, `RationalQ`, `ComplexNumberQ`, `RealNumericQ`, `SqrtNumberQ`, `SqrtNumberSumQ`, `FractionOrNegativeQ`, `FractionalPowerOfSquareQ` |
| **Integer comparison** | `IGtQ`, `ILtQ`, `IGeQ`, `ILeQ`, `IntegersQ` |
| **General comparison** | `EqQ`, `NeQ`, `GtQ`, `LtQ`, `GeQ`, `LeQ` |
| **Algebraic** | `ZeroQ`, `NonzeroQ`, `PositiveQ`, `NegativeQ`, `OddQ`, `EvenQ` |
| **Structural** | `PolynomialQ`, `LinearQ`, `QuadraticQ`, `BinomialQ`, `TrinomialQ`, `PowerQ`, `SumQ`, `ProductQ`, `IntegerPowerQ`, `FractionalPowerQ`, `QuotientOfLinearsQ` |
| **Function-type** | `TrigQ`, `HyperbolicQ`, `InverseTrigQ`, `InverseHyperbolicQ`, `LogQ`, `InverseFunctionQ`, `ElementaryFunctionQ`, `AlgebraicFunctionQ`, `AlgebraicTrigFunctionQ`, `RationalFunctionQ` |
| **Calculus-aware** | `CalculusQ`, `CalculusFreeQ`, `IntegralFreeQ`, `TrigHyperbolicFreeQ`, `FunctionOfTrigOfLinearQ` |
| **Function-of** | `FunctionOfQ`, `FunctionOfExponentialQ`, `FunctionOfExponentialTest`, `PureFunctionOfSinQ`, `PureFunctionOfCosQ`, `PureFunctionOfTanQ`, `PureFunctionOfCotQ`, `FunctionOfSinQ`, `FunctionOfCosQ`, `FunctionOfTanQ`, `FunctionOfSinhQ`, `FunctionOfCoshQ`, `FunctionOfTanhQ`, `FunctionOfHyperbolicQ`, `FunctionOfTrigQ`, `FractionalPowerSubexpressionQ` |
| **Logical** | `And`, `Or`, `Not` |

---

## File Organisation

```
rules/
├── meta.json                        # Load manifest, feature flags, taxonomy
├── 1-algebraic/
│   ├── 1.1-binomial/
│   │   ├── 1.1.1-linear/
│   │   │   ├── 1.1.1.1-(a+b-x)^m.json
│   │   │   └── 1.1.1.2-(a+b-x)^m-(c+d-x)^n.json
│   │   ├── 1.1.2-quadratic/
│   │   ├── 1.1.3-general/
│   │   └── 1.1.4-improper/
│   ├── 1.2-trinomial/
│   └── 1.3-miscellaneous/
├── 2-exponentials/
├── 3-logarithms/                    # ← Section 3 = Logarithms (not trig!)
├── 4-trig/
│   ├── 4.1-sine/                    # No 4.2 — Cosine normalized to Sine
│   ├── 4.3-tangent/                 # No 4.4 — Cotangent normalized to Tangent
│   ├── 4.5-secant/                  # No 4.6 — Cosecant normalized to Secant
│   └── 4.7-miscellaneous/
│       ├── 4.7.5-inert-trig.json    # Inert trig function rules
│       └── 4.7.9-active-trig.json   # Active trig function rules
├── 5-inverse-trig/
├── 6-hyperbolic/
├── 7-inverse-hyperbolic/
├── 8-special/
│   ├── 8.1-error-functions.json
│   ├── ...
│   ├── 8.9-product-logarithm.json
│   └── 8.10-bessel.json             # Conditionally loaded
└── 9-miscellaneous/
tests/
├── 1-algebraic/
└── ...
schemas/
├── osr-expr.schema.json
├── rule-file.schema.json
├── meta.schema.json
└── test-file.schema.json
```

Note the **even-numbered subsection gaps** in sections 4–7 (e.g. no 4.2, 4.4, 4.6). RUBI normalizes co-function rules to their primary form (Cosine → Sine, Cotangent → Tangent, etc.) so co-function subsections don't exist.

---

## Optional: Binary Cache (CBOR)

For fast machine loading of ~7,800 rules, an optional [CBOR](https://cbor.io/) (RFC 8949) binary cache can be compiled from JSON. CBOR preserves the exact JSON data model with lossless round-trips, and typically achieves 60–70% of JSON size at 2–5× faster parse speed.

JSON remains canonical and git-versioned; CBOR is a derived artifact, never authoritative.

---

## Interoperability Strategy

### Phrasebook Architecture

Each host CAS provides a thin **Phrasebook** adapter that translates between OSR-Expr and the host's internal representation. This is the **only** CAS-specific code. The rule files, test fixtures, loader logic, and taxonomy remain universal.

```
JSON rules  ──→  Phrasebook  ──→  Host CAS
                 (Julia / Python / Java / Rust / JS)
```

The Phrasebook has three responsibilities:
1. **Map operator names** to host CAS functions
2. **Implement utility functions** (~55 functions: NormalizeIntegrand, Rt, SimplifyAntiderivative, etc.)
3. **Implement inert trig mechanism** (ActivateTrig/DeactivateTrig — may be a no-op in CAS environments that don't auto-simplify)

### Mapping to Standards

The spec includes normative mapping tables (Annex A) to:
- **MathLive MathJSON** — identity for most operators, explicit translation for inverse trig/hyp
- **OpenMath Content Dictionaries** — `arith1#plus`, `transc1#sin`, etc.
- **Content MathML** — `<plus/>`, `<sin/>`, etc.

The format doesn't *depend* on any of these — it's self-contained — but it's *traceable* to formal standards.

---

## What I'm Asking For

1. **Completeness check.** The v0.1 catalogue was built by auditing the actual RUBI repo, but there are ~7,800 rules and I haven't parsed every one. Are there predicates, utility functions, or operators still missing? I'd especially appreciate review from anyone who has worked on the Mathematica-to-SymJa or Mathematica-to-SymPy converters.

2. **Feedback on the expression encoding.** Is the S-expr-in-JSON approach (`["Add", 1, "x"]`) acceptable, or would the community prefer a different encoding?

3. **Feedback on the load-order manifest.** The `meta.json` `load_order` array preserves RUBI's exact file loading sequence. Is this the right abstraction, or should priority be encoded differently (e.g. per-rule priority integers, or implicit from section numbering)?

4. **Inert trig function mechanism.** The spec models this via `ActivateTrig`/`DeactivateTrig` utility functions. Is there a better way to represent inert vs. active forms in JSON? Should inert operators have their own names (`sin_inert` vs `Sin`)?

5. **Utility function boundary.** The spec separates "operators" (declarative, appear in JSON) from "utility functions" (algorithmic, implemented by each Phrasebook). Is the boundary drawn in the right place?

6. **Interest in collaboration.** Would the RUBI-5 project consider adopting (or co-maintaining) a JSON export alongside the Mathematica source? Even a one-way Mathematica → JSON converter maintained upstream would be transformative.

7. **Test fixture scope.** The spec targets the full 72,000+ test problems. Is the test suite available for conversion, and are there licensing considerations beyond MIT?

---

## Relevant Prior Art

- [RUBI 4.16+](https://rulebasedintegration.org/) — the rule set this format targets
- [RUBI 5](https://github.com/RuleBasedIntegration/Rubi-5) — the if-then-else decision tree redesign (~7,800 rules)
- [SymJa](https://github.com/axkr/symja_android_library) — Java port with its own RUBI conversion
- [SymPy RUBI](https://github.com/sympy/sympy_rubi) — Python port (`utility_function.py` and `constraints.py` were key references)
- [MathLive MathJSON](https://cortexjs.io/math-json/) — JSON math expression format (partial alignment)
- [OpenMath 2.0](https://openmath.org/) — formal semantics standard (mapping provided)
- [MathML Content](https://www.w3.org/TR/MathML3/) — W3C standard (mapping provided)

---

## Full Spec and Schema

The complete EARS specification (**159 requirements** across 13 categories) and **4 JSON Schema files** are available for review:

- **EARS spec:** 27 expression language requirements, 18 file format (including load manifest), 20 binary cache, 7 wildcard/matching, 23 predicates, 5 taxonomy, 14 engine (including inert trig), 18 portability — plus normative Annex A mapping tables
- **JSON Schema:** `osr-expr.schema.json` (17 definitions, all operator enums), `rule-file.schema.json`, `meta.schema.json` (15 properties including `load_order`, `feature_flags`), `test-file.schema.json` — all validated with example files

Happy to share the full documents or specific sections on request.

---

**I'd love to hear from RUBI maintainers, CAS developers, and anyone interested in making symbolic integration rules truly portable.** The format is designed to serve RUBI — not to compete with it.