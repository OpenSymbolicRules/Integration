# OSR v1 files

`v1/` holds the RUBI rules that the OSR v1 fragment can state, in the OSR v1
interchange format (Specification, `docs/osr-v1.md`).  These files are
generated, never edited by hand:

| File | Content |
|---|---|
| `v1/integration.osr.json` | 47 antiderivative rules `int(λx. F) ⟶ λx. G` (`calculus1#int`, lambdas as `OMBIND fns1#lambda`), with verification records over ℝ and ℂ. |
| `v1/integration.report.json` | Machine-readable audit: metrics per domain and the rules not migrated. |
| `v1/integration.report.md` | The same audit for humans, with the findings of every rule. |

## Where they come from

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
- eight are **false** as converted, each with a Lean proof of its negation
  (status `counterexample`): `∫ 1/x = log x` at `x = −1`, where the real
  logarithm is undefined, and seven rules whose result divides by a
  coefficient that the conditions allow to vanish (`b`, `c`, `d`, `e` or
  `n` equal to 0).  The missing conditions are recorded as findings, not
  added;
- seven are not migrated: their integrands are powers with the exponent
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

## Updating

```bash
just update-v1 <Verification>/reports/<digest>
```

Then update the Verification commit pinned in the CI workflow.
