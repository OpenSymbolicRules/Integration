# OSR v1 files

`v1/` holds the RUBI rules that the OSR v1 fragment can state, in the OSR v1
interchange format (Specification, `docs/osr-v1.md`).  These files are
generated, never edited by hand:

| File | Content |
|---|---|
| `v1/integration.osr.json` | 6 antiderivative rules `int(λx. F) ⟶ λx. G` (`calculus1#int`, lambdas as `OMBIND fns1#lambda`), with verification records over ℝ and ℂ. |
| `v1/integration.report.json` | Machine-readable audit: metrics per domain and the rules not migrated. |
| `v1/integration.report.md` | The same audit for humans, with the findings of every rule. |

## Where they come from

1. `OpenSymbolicRules/Lean` states each rule with Mathlib's analysis
   (`OSR/Integration.lean`): wherever the integrand is defined on a
   neighbourhood of a point, the result is defined on a neighbourhood of that
   point and has the integrand as derivative there (`HasDerivAt`).
2. `OpenSymbolicRules/Verification` publishes the export under
   `reports/<source digest>/` and can rebuild it independently.
3. This repository copies the published files.  The CI checks that they
   validate against the v1 schema, share one source digest, and are
   byte-identical to the published report.

## Scope

`scripts/inventory_v1.py` (`just inventory`) counts the rules syntactically.
A candidate has only `FreeQ` constraints, no `Int` in its result, and only
heads that the OpenMath registry interprets once its outer `Int` is removed.
With the registry of report `68dfb6f0…`, nine of the 6,257 rules are
candidates.  The counts establish neither migratability nor correctness.

Of the nine candidates:

- `∫ a = a x` is proved over ℝ and ℂ, and `∫ log(c xⁿ) = x log(c xⁿ) − n x`
  over ℝ;
- four rules are **false** as converted, each with a Lean proof of its
  negation (status `counterexample`): `∫ 1/x = log x` at `x = −1`, where
  the real logarithm is undefined; `∫ a (b + c x)` at `c = 0`;
  `∫ (a + b log(c xⁿ))/x` at `b = n = 0`; the `log log` rule at `n = 0`.
  The missing conditions are recorded as findings, not added;
- three are not migrated: their integrands are powers with the exponent
  `3/2` or an exponent depending on `x`, while the fragment interprets
  `arith1#power` for integer exponents only.

## Differences from v0.1

The v0.1 files in `rules/` remain the RUBI corpus.  In v1:

- `Int[F, x]` becomes `calculus1#int` applied to `λx. F`;
- an n-ary `Multiply` or `Add` becomes a left-nested binary chain, and
  `Power[u, -1]` stays a power;
- an optional wildcard (`c.`, `n.`, …) becomes an ordinary metavariable,
  so a v1 rule matches only the explicit form;
- `FreeQ` becomes an `independent` matching constraint;
- a rule applies at the root of an `int` term and keeps the input's bound
  variable; its result is a lambda, so normalization takes one step at most.

## Updating

```bash
just update-v1 <Verification>/reports/<digest>
```

Then update the Verification commit pinned in the CI workflow.
