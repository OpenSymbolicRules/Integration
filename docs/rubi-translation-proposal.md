# RUBI multiline conversion: semantic decisions for review

This proposal does not change the OSR specification or publish candidate
rules. Evidence is the pinned RUBI commit
`61e9c18ea248061cd83c67882f7c91a73cef912d`, whose `Rubi/PacletInfo.m`
declares `4.17.3.0`. The historical Integration metadata labels the corpus
`4.16.1`; the discrepancy requires an audit rather than a silent relabelling.

## `Star` is not an ordinary formatting marker

RUBI's `IntegrationUtilityFunctions.m`, section `Star[u,v]`, describes a
product with distribution. Its implementation also depends on `$ShowSteps`,
whether the second operand contains integrals, zero factors, and nested
`Star` expressions. A CAS using ordinary multiplication may produce a different
intermediate expression or evaluation trace, even where the intended
mathematical value is a product. This matters when later rewrite order is
significant.

Candidate approaches, neither implemented as a rule export here:

1. **Preserve the operation.** Agree on a versioned, reviewed vocabulary and
   an operational contract for `Star`; consumers that cannot execute it must
   explicitly decline it. This best preserves the source expression but needs
   a vocabulary decision outside the current Integration converter.
2. **Offer a restricted value-level profile.** Translate to mathematical
   multiplication only when an explicit contract establishes the intended
   evaluation regime and acceptable loss of operational behavior. This needs
   a proof or review of definedness, distribution and affected downstream
   rewrites. It must not be labelled execution-equivalent to RUBI by default.

Until one path is reviewed, the converter keeps `Star` in its internal syntax
and rejects affected files instead of inventing an OpenMath symbol or
publishing a silent replacement.

## Local bindings

OSR v0.1's structural catalogue mentions `With`, `Module` and `Set`, but a
converter and consumer still need a shared account of lexical binding,
evaluation order and variable capture. For example, a local `k` in
`With[{k=Denominator[m]}, body]` must not capture a free `k` in a substituted
expression. The parser recognizes these constructs, but export currently
rejects them. A future implementation should test nested scopes, shadowing,
simultaneous definitions, free variables and unsupported constructs, and
document which consumers can execute the resulting form. A capture-avoiding
elaboration is an alternative only when its equivalence is established.

`Module` cannot be converted wholesale to `With`. In the pinned 1.4.1 source,
`Module[{q=Expon[Pq,x],r=Expon[Qr,x]}, ...]` creates local names used by a
guarded body. Other pinned rules declare an uninitialized local, for example
`Module[{k}, ...]`; the 4.7.5 trigonometric source also contains a local
declared first and assigned later inside a `CompoundExpression`. In addition
to capture avoidance, any implementation must preserve fresh names, assignment
and evaluation order, and the lifetime of values under held expressions.
Until these cases have a reviewed contract and executable consumer tests,
`Module` stays blocked in rule export. A static validator alone cannot prove
runtime equivalence.

## Source order and identifiers

RUBI's `Rubi.m` orders loaded files. The default `meta.json` now follows the
source-file sequence, and the manifest updater preserves it. The read-only
audit records the exact upstream revision, active load calls,
configuration and the source file path for each entry. A legacy local rule ID
is a locator, not itself a proved global execution rank. Rules from files not
loaded by that RUBI configuration, unavailable rules, and OSR-only variants
must not receive invented upstream ranks. Tests must cover commented calls,
conditional loads, duplicate paths and unmatched entries before use by a CAS.

## Remaining syntax

An earlier cell audit reported 22 candidate cells that did not parse, including
compound heads, derivative notation and the `=!=` operator. Compound heads are
now retained as AST applications but still rejected at export; postfix prime
notation is likewise retained in the AST and rejected at export. The pinned
derivative source now parses as 21 code expressions. Their Wolfram semantics and the
available OSR representations require separate tests. Cell parse counts are
not a substitute for schema validation, numerical checks or formal proof.

The official [OpenMath `calculus1#nthdiff`](https://openmath.org/cd/calculus1#nthdiff)
describes iterated ordinary differentiation of a unary function, with the
order and function as its arguments. It is a candidate for an explicitly
bounded nonnegative-order subset, subject to an application representation
and consumer review. It is not by itself a justified mapping for every RUBI
case: the pinned source also contains `ILtQ[n,0]` rules, and Wolfram documents
that [negative-order `Derivative` can perform integrals](https://reference.wolfram.com/language/ref/Derivative.html).
The source also includes a derivative pattern without an explicit order guard.
Those cases require a separately specified meaning, including integration
constants and applicability, rather than silently treating all orders as
ordinary differentiation. No mapping is enabled by this observation.

The source has materially different applicability cases: the first rule has
no explicit integer or sign guard on `n`; other rules use `IGtQ[n,0]` or
`ILtQ[n,0]`; still others use fixed derivative order `1` or symbolic orders
related by `EqQ`. A future translation must retain each original condition,
not silently replace the unrestricted rule with a positive-order variant.

The OSR expression schema requires a string in function-head position, while
the OpenMath derivative applies a derivative operator to a function and then
applies the resulting function to its argument. The catalogue's `Apply` has
arity two and takes a head and a list of arguments. An illustrative design
for a reviewed positive-order subset could therefore use an application of a
mapped `nthdiff` expression to a one-element argument list. This is a proposal,
not a current conversion contract: pattern-variable binding in function
position, operator semantics, host evaluation and the treatment of negative
orders must be reviewed and tested. In particular, the MathJSON examples in
the specification use a different-looking `Apply` shape and should not be
assumed to establish the OSR calling convention.

## Real proofs for the three first-derivative rules

The last three source cells of Rubi 4.17.3.0 section 9.1 use ordinary first derivatives. Let f and g be real functions differentiable at x. Write p = f′(x), q = g′(x), F = f(x) and G = g(x). The table gives the derivative of each proposed primitive at x. Every function stays abstract throughout the proof. [Pinned source cells 19–21](https://github.com/RuleBasedIntegration/Rubi/blob/f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4/Rubi/IntegrationRules/9%20Miscellaneous/9.1%20Derivative%20integration%20rules.m#L143-L157) · [Lean statements and proofs](../verification/RubiDerivativePrimitives.lean)

| Source cell | Primitive as a function of t | Derivative at x | Additional real-domain hypothesis | Lean theorem in `OSR.Rubi` |
|---|---|---|---|---|
| 19 | f(t)g(t) | pG + Fq | None | `product` |
| 20 | f(t)/g(t) | (pG − Fq)/G² | G ≠ 0 | `quotient` |
| 21 | log(f(t)/g(t)) | (pG − Fq)/(FG) | G ≠ 0 and F/G > 0 | `logQuotient` |

Rubi checks `FreeQ[{f,g},x]` on the function heads in all three cells. It places no sign or denominator test in these guards. A real CAS must also establish differentiability and the relevant domain hypotheses before using these results. For cell 21, F = G = −1 gives an admissible real logarithm, whereas F = 1 and G = −1 gives a negative logarithm argument. Lean's real logarithm extends to negative inputs. The positivity hypothesis restricts the theorem to the intended real branch. [Mathlib real logarithm](https://github.com/leanprover-community/mathlib4/blob/56a005855ea17e0b0958f73ec801ae140b0a1679/Mathlib/Analysis/SpecialFunctions/Log/Basic.lean)

Run `just real-proofs /path/to/prepared/Lean` to check all three manually transcribed statements under the Integration report's toolchain and audit their axioms. The source ledger still records these cells among the 21 omissions in section 9.1. Publishing executable patterns requires binding f and g in function position and reusing the same bindings in the result. The three real proofs add no entries to the generated v1 catalogue. [Release coverage ledger](../editions/rubi-4.17.3.0/coverage.json) · [Verification pins](../v1/integration.report.json)
