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
compound heads, derivative notation and the `=!=` operator. The parser retains all 21 expressions in the derivative section. The release converter exports six cells, three with a single prime and three with an explicit positive integer order. The coverage ledger retains the other 15 cells and their source ordinals. Three of these, cells 16–18, admit p=q=−1 although the result divides by p+1. Their input integrands can be finite at the same point. [Counterexample and reproduction](../upstream-bugs.md)

### Integration by parts with positive integer order

In cells 2, 4 and 5 the source guard `IGtQ[n,0]` establishes that n is a positive integer. Each rule rewrites an integral of a weight times the n-th derivative of f using a derivative of order n−1. At n = 1 that derivative is f itself. Constants in the weight and the function head f must satisfy the original `FreeQ` check. [Release JSON](../editions/rubi-4.17.3.0/rules/9-miscellaneous/9.1-Derivative-integration-rules.json) · [OpenMath iterated differentiation](https://openmath.org/cd/calculus1.html#nthdiff)

| Source cell | Weight | Residual integral term in the primitive, with u = f⁽ⁿ⁻¹⁾ |
|---|---|---|
| 2 | W = (c F^(a+bx))^p | −bp log(F) ∫ W u dx |
| 4 | sin(a+bx) | −b ∫ cos(a+bx) u dx |
| 5 | cos(a+bx) | +b ∫ sin(a+bx) u dx |

In each case the leading term is the weight times u. The JSON retains Rubi's `Star` operator for distributing the coefficient over the residual integral. A real analytic application also needs the indicated derivatives and a differentiable weight on the integration interval. For the exponential weight, positive F and c with real parameters suffice. These domain requirements are separate from the two source guards.

The checked real theorems write n = k + 1 for a natural number k and assume that f is locally of class Cⁿ at x. The exponential theorem additionally requires F > 0 and c > 0. For any function R whose derivative at x equals the residual integrand there, Lean verifies that the derivative of the complete right-hand side equals the original integrand. This checks the sign, coefficient, order and weight for every choice of integration constant, including at k = 0. The theorems are `OSR.Rubi.exponentialParts` (cell 2), `OSR.Rubi.sineParts` (cell 4) and `OSR.Rubi.cosineParts` (cell 5). The Lean statements were transcribed manually from the release JSON. These proofs are recorded outside the v1 catalogue. [Lean proofs](../verification/RubiDerivativeRecurrences.lean) · [Original source](https://github.com/RuleBasedIntegration/Rubi/blob/f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4/Rubi/IntegrationRules/9%20Miscellaneous/9.1%20Derivative%20integration%20rules.m#L29-L49)

The expression `["Apply", ["Derivative", n], ["List", f]]` denotes the derivative function. An outer `Apply` evaluates it at the argument. For nonnegative integer n the complete inner application corresponds to OpenMath `calculus1#nthdiff(n,f)`. The release converter requires a positive integer guard before exporting a symbolic order and its predecessor. A missing guard, a guard on a different variable, or a disjunction permitting negative orders cannot justify that conversion. Negative-order Wolfram derivatives can denote integrals and need separate semantics. [Wolfram Derivative](https://reference.wolfram.com/language/ref/Derivative.html) · [OpenMath calculus dictionary](https://openmath.org/cd/calculus1.html)

Each of the six published JSON entries carries the qualified Lean theorem name and an immutable source link in `references`. The linked declaration gives its exact real-domain hypotheses. The converter attaches these citations only to the reviewed Rubi file digest and source ordinals. Consumers can use them to inspect proof evidence independently of the source `constraints` used for matching. [Six rule records](../editions/rubi-4.17.3.0/rules/9-miscellaneous/9.1-Derivative-integration-rules.json)

## Real proofs for the three first-derivative rules

The last three source cells of Rubi 4.17.3.0 section 9.1 use ordinary first derivatives. Let f and g be real functions differentiable at x. Write p = f′(x), q = g′(x), F = f(x) and G = g(x). The table gives the derivative of each proposed primitive at x. Every function stays abstract throughout the proof. [Pinned source cells 19–21](https://github.com/RuleBasedIntegration/Rubi/blob/f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4/Rubi/IntegrationRules/9%20Miscellaneous/9.1%20Derivative%20integration%20rules.m#L143-L157) · [Lean statements and proofs](../verification/RubiDerivativePrimitives.lean)

| Source cell | Primitive as a function of t | Derivative at x | Additional real-domain hypothesis | Lean theorem in `OSR.Rubi` |
|---|---|---|---|---|
| 19 | f(t)g(t) | pG + Fq | None | `product` |
| 20 | f(t)/g(t) | (pG − Fq)/G² | G ≠ 0 | `quotient` |
| 21 | log(f(t)/g(t)) | (pG − Fq)/(FG) | G ≠ 0 and F/G > 0 | `logQuotient` |

Rubi checks `FreeQ[{f,g},x]` on the function heads in all three cells. It places no sign or denominator test in these guards. A real CAS must also establish differentiability and the relevant domain hypotheses before using these results. For cell 21, F = G = −1 gives an admissible real logarithm, whereas F = 1 and G = −1 gives a negative logarithm argument. Lean's real logarithm extends to negative inputs. The positivity hypothesis restricts the theorem to the intended real branch. [Mathlib real logarithm](https://github.com/leanprover-community/mathlib4/blob/56a005855ea17e0b0958f73ec801ae140b0a1679/Mathlib/Analysis/SpecialFunctions/Log/Basic.lean)

Run `just real-proofs /path/to/prepared/Lean` to check all three manually transcribed statements under the Integration report's toolchain and audit their axioms. The v0.1 release transcribes the original guards and retains source ordinals 19–21. Its manifest declares the unary Wolfram `Derivative` operator. Applying `Derivative[1]` to a function has the OpenMath meaning `calculus1#diff`. A CAS adapter must preserve that function binding at every occurrence. The three real proofs concern the hypotheses in the table. They add no entries to the generated v1 catalogue. [Published JSON](../editions/rubi-4.17.3.0/rules/9-miscellaneous/9.1-Derivative-integration-rules.json) · [OpenMath ordinary differentiation](https://openmath.org/cd/calculus1.html#diff) · [Release coverage ledger](../editions/rubi-4.17.3.0/coverage.json) · [Verification pins](../v1/integration.report.json)

In the pattern below, `f_` binds the function and `x_` binds its argument. The integration variable also appears as `x_symbol`. After matching f to h and x to z, the result expression evaluates h at z. A second occurrence of `f_` must match the same h.

| Source occurrence | OSR expression |
|---|---|
| First derivative in a pattern, f′(x) | `["Apply", ["Apply", ["Derivative", 1], ["List", "f_"]], ["List", "x_"]]` |
| Ordinary call in the same pattern, f(x) | `["Apply", "f_", ["List", "x_"]]` |
| Ordinary call in the result, f(x) | `["Apply", "f", ["List", "x"]]` |
