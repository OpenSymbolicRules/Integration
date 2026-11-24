# OSR v1 files

`v1/` holds the RUBI rules that the OSR v1 fragment can state, in the OSR v1
interchange format (Specification, `docs/osr-v1.md`).  These files are
generated, never edited by hand:

| File | Content |
|---|---|
| `v1/integration.osr.json` | 2884 integration rules (`calculus1#int`, lambdas as `OMBIND fns1#lambda`), with verification records over ℝ and ℂ. |
| `v1/integration.report.json` | Machine-readable audit: metrics per domain and the rules not migrated. |
| `v1/integration.report.md` | The same audit for humans, with the findings of every rule. |

## Where they come from

RUBI 5.3.7 #19 is retained with its original equality condition and a
Lean-checked counterexample over ℝ: at `a = 2`, `b = -1`, `c = 1`, and
`x = -1`, the integrand is defined locally but the result's real logarithm
is not. Its complex status is unproved; the fragment has no complex square
root interpretation. A counterexample is not a verified rewrite.

RUBI 1.1.1.2 #21 is proved over ℝ under its original conditions `a+c=0`,
`b-d=0`, and `a>0`; local definedness supplies the required strict domain.
RUBI 7.3.7 #19 is retained with a Lean-checked real counterexample at
`a=3`, `b=c=1`, `x=-1`. Both have unproved complex status because the
fragment does not interpret their complex square roots and inverse functions.

RUBI 2.3 #1 is retained with its original independence constraint and a
Lean-checked real counterexample: at `F=2`, `a=b=0`, `c=n=1`, the
integrand is defined everywhere but the replacement divides by zero. The
complex case is unproved. RUBI 2.3 #8 has the analogous real counterexample
at `F=2`, `a=b=0`, `c=d=1`; its complex case is also unproved. The source at revision `61e9c18` declares version
4.17.3.0; the v0.1 rule's 4.16.1 version label is historical. The proof
concerns the mathematical rule, not runtime dispatch in RUBI.

The strengthened variant of RUBI 4.1.1.1 #11 integrates
`(a + b sin(c + d x))^2` and is proved over ℝ and ℂ under `d ≠ 0`. The
original rule remains refuted because its stated conditions omit this guard.

Ten more strengthened variants are proved over ℝ; seven are also proved
over ℂ, including two with residual integrals. They cover half-angle and quartic sine primitives, cosecant,
exponential-arctangent and hyperbolic primitives. Their additional nonzero
conditions are retained, and their original rules remain separately refuted.

Four strengthened recursive hyperbolic-power variants (6.1.13 #11–14) are
proved and certified over ℝ, including at zero bases. Their complex Lean
statements also compile, but are not certified: the fragment compares real
parts of real-valued complex numbers, and the registry marks the complex order
mapping unsupported. The original rules remain separately refuted.

Four additional strengthened recursive hyperbolic-power variants (6.1.13
#15–18) are proved and certified over ℝ for negative exponents; the
integrand's definedness supplies the locally nonzero power base. Their
complex Lean statements compile but are not OSR-certified because complex
order is unsupported. Their original rules remain separately refuted.

All twelve strengthened variants in the 6.1.13 #7–18 family are now
proved and certified over ℝ. They also have checked complex Lean theorems:
#7–10 are certified, while #11–18 use the unsupported complex order mapping
and are not certified for OSR.

Independently proved generalized variants may replace the source rule's
conditions; the structural checker reports these separately and does not
itself establish their proofs (Specification V1-R-005f).

1. `OpenSymbolicRules/Lean` states each rule with Mathlib's analysis
   (`OSR/Integration.lean`): wherever the integrand is defined on a
   neighbourhood of a point, the result is defined on a neighbourhood of that
   point and has the integrand as derivative there (`HasDerivAt`), for every
   assignment of the metavariables satisfying the rule's conditions.
2. `OpenSymbolicRules/Verification` publishes the export under
   `reports/<source digest>/` and can rebuild it independently.
3. This repository copies the published files.  The CI checks that they
   validate against the v1 schema, share one source digest, and are
   byte-identical to the published report.

## Scope

`scripts/inventory_v1.py` (`just inventory`) counts the rules syntactically.
A candidate has no `Int` in its result, only heads that the OpenMath
registry interprets once its outer `Int` is removed, and only constraints
with a counterpart among the conditions of the fragment: `FreeQ`, `NeQ`,
`GtQ`, `LtQ`, `IntegerQ`, `IntegersQ`, `IGtQ`, `ILtQ`.  With the registry of
OpenSymbolicRules/OpenMath, twenty of the 6,257 rules are candidates: nine
with `FreeQ` only and eleven with `NeQ`.  The counts establish neither
migratability nor correctness.

Of the twenty candidates:

- five are proved: `∫ a = a x` and the power rule `∫ xᵐ = xᵐ⁺¹/(m+1)`
  (`m ≠ −1`, integer values of `m`) over ℝ and ℂ; `∫ log(c xⁿ)` and the
  `sin`/`cos` of `d (a + b log(c xⁿ))` over ℝ;
- ten are **false** as converted, each with a Lean proof of its negation
  (status `counterexample`): `∫ 1/x = log x` at `x = −1`, where the real
  logarithm is undefined, and nine rules whose result divides by a
  coefficient that the conditions allow to vanish (`b`, `c`, `d`, `e` or
  `n` equal to 0).  The missing conditions are recorded as findings, not
  added;
- five are not migrated: their integrands are powers with the exponent
  `3/2` or an exponent depending on `x`, while the fragment interprets
  `arith1#power` for integer exponents only.

Conditional rules carry their conditions (`relation1#neq`); engines that
cannot decide them, such as the Lean reference rewriter and
OpenSymbolicRules.jl, do not apply them.

## Residual integrals

Most RUBI rules have another `Int` in their result.  In v1 it becomes a
residual integral `int(λx. H)(x)`, the form of the `calculus1#int` FMP
(Specification V1-E-002b).  The rule states that the residual integrands are
defined wherever the integrand is, and that for every choice of
antiderivatives of them the result is an antiderivative of the integrand.
Engines that do not continue inside residual integrals do not apply these
rules (V1-R-005c).

272 recursive rules have registered heads, expressible conditions and a
result linear in their residual integrals.  Eleven of them, without square
roots or fractional exponents, are migrated: the addition and half-angle
splits of `sin`/`cos` (4.1.12 #3, #4, #25, #26, #39, #40) are proved over ℝ
and ℂ, the reduction of `(a + b log(c xⁿ))ᵖ` (3.1.1 #2) over ℝ, and four
rules are false as converted (3.5 #1 at `p = 0`, where the residual
integrand `1/log(d xⁿ)` is undefined; 4.7.8 #45, #46 at `a = 0`; 1.2.1.2 #14
at `c = 0`).

A second batch of eleven, among the rules whose wildcards are all `FreeQ`:
the partial fractions of `1/((a + b xⁿ)(c + d xⁿ))` (1.1.1.2 #3, 1.1.3.3 #19)
and two linearity splits (1.1.3.5 #11, 1.2.1.6 #13) are proved over ℝ and ℂ;
seven rules divide by a coefficient that their conditions allow to vanish
(4.1.13 #17, #18, 1.2.1.2 #13, 1.2.1.3 #11, #12, 1.1.3.5 #10) or, at
`p = 0`, leave the residual integrand `xⁿ/0` (3.4 #1), and are refuted.

A third batch of twelve: three partial fraction decompositions (1.2.1.2 #78,
#79, 1.1.3.4 #63) and `sin u cos u = sin(2u)/2` (4.7.9 #68) are proved over ℝ
and ℂ; eight rules are refuted (1.1.3.5 #2, 1.1.1.4 #17, 4.1.13 #3, #4,
1.1.3.3 #14, 3.5 #3, 1.1.1.3 #8, 3.4 #7).

A fourth batch of 25, transcribed by a tool and checked by
`scripts/v1_faithfulness.py`: one linearity split (3.3 #44) is proved; 22
rules are refuted because a coefficient the result divides by may vanish or,
at `n = 0`, a residual integrand divides by `d + e x`; 3.3 #4 and 3.1.3 #3
are refuted over ℝ, where `log` is evaluated at a negative point.  Seven
rules whose integrand is `F^(…)` with an exponent depending on `x` were not
migrated in that batch; 2.3 #1 and #8 have since been added as real counterexamples.

A fifth batch widens the scope to exponents that RUBI constrains only by
numeric predicates (`IntegerQ`, `GtQ`, …), declared independent of `x` with
an `independence:` finding.  A numerical search proposes counterexamples
under the fragment's real definedness semantics, and each is proved in
Lean per domain: 45 more rules are refuted, and the reduction 1.2.1.2 #83
is proved.

Five further rules are refuted over both ℝ and ℂ: RUBI 4.16.1 rules
1.2.2.4 #57 and #58, 2.1 #10, and 4.1.12 #45 and #46. Their original
conditions allow coefficients to vanish in result denominators. The Lean
4.35.0 proofs (Mathlib `56a005855ea17e0b0958f73ec801ae140b0a1679`)
use assignments at `x = 1` where the integrand is defined nearby and the
result is undefined; no missing condition is added silently.

The current set has 511 proved, 1578 refuted and 795 unproved rules over ℝ;
over ℂ, 318 are proved (166 certified), 377 refuted and 2189 unproved.

The inventory excludes rules whose result or conditions use a name the
pattern does not bind (739 rules, 630 of them with `E`, `ImaginaryI` or
`Pi`; see [known issues](known-issues.md) §4).

## Differences from v0.1

The v0.1 files in `rules/` remain the RUBI corpus.  In v1:

- `Int[F, x]` becomes `calculus1#int` applied to `λx. F`;
- an n-ary `Multiply` or `Add` becomes a left-nested binary chain, and
  `Power[u, -1]` stays a power;
- an optional wildcard (`c.`, `n.`, …) becomes an ordinary metavariable,
  so a v1 rule matches only the explicit form;
- `FreeQ` becomes an `independent` matching constraint, and `NeQ[a, b]` the
  condition `a ≠ b`, read semantically;
- a rule applies at the root of an `int` term and keeps the input's bound
  variable; its result is a lambda, so normalization takes one step at most.

## Faithfulness

`scripts/v1_faithfulness.py` converts each v0.1 rule named by a v1
`legacy_id` with the conventions above and requires the v1 pattern,
replacement and conditions to be the resulting OpenMath objects, and its
`independent` variables to be the `FreeQ` ones (more only with an
`independence:` finding).  A *strengthened* rule (Specification V1-R-005e, a
corrected variant with an id ending in `_nondegenerate`) may append
conditions after the converted ones only with a `strengthened:` finding; the
script counts such rules separately (`N faithful, M strengthened, K
different`).  `scripts/check-v1.sh` runs it.

The v0.1 heads follow the converter's `OPENMATH_SEMANTICS`
(`converter/src/rule_writer.jl`): besides `arith1`, `calculus1#int` and
`transc1#ln`, the reciprocal, hyperbolic and inverse functions map to their
`transc1` symbols (`Cot` → `cot`, `Sinh` → `sinh`, `Asin` → `arcsin`,
`Atanh` → `arctanh`, …), `Abs` to `arith1#abs`, and any other head to
`osr#<head>`.  `Sqrt[a]` (`arith1#root`) is read as the square root
`root(a, 2)`, a power `E^u` of the constant `E` as the exponential
`exp(u)` (`transc1#exp`), `Simp[e]` and `Simp[e, x]` as `e`, `Acoth[u]` as `arctanh(u^-1)`, `Subst[Int[H, x], x, g]` as
`int(λx. H)(g)`, `Acot[u]` as `arctan(u^-1)`, the inert
`sin`, `cos`, `tan`, `cot`, `sec` and `csc` as the trig functions, and `EqQ` is an expressible
condition (`relation1#eq`); `And[…]` conditions are flattened, `Not[EqQ]`
reads as `NeQ` and `Not[NeQ]` as `EqQ`, `GeQ` and `Not[LtQ]` as
`relation1#geq`, `LeQ` and `Not[GtQ]` as `relation1#geq` with the operands
swapped, and `Or` as a left-nested `logic1#or`; compound conditions are first put in
conjunctive normal form (`Or` distributes over `And`, `Not` moves inward), at most 16
clauses per condition.

## Updating

```bash
just update-v1 <Verification>/reports/<digest>
```

Then update the Verification commit pinned in the CI workflow.
