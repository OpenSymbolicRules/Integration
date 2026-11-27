# Upstream bugs

## RUBI 4.5.2.1, source line 51, OSR rule 47

The [released 4.17.3.0 edition](docs/rubi-release.md) contains the same residual at source cell 48, with an operational Star product. It has a separate fingerprint and skip record.

John Verzani reported a mismatch between the integrand and the residual
integral in RUBI revision `61e9c18ea248061cd83c67882f7c91a73cef912d`
(the pinned loader declares 4.17.3.0). The pattern contains inert cosecant,
the prefactor contains active cosecant, and the residual integral contains
two cosines. The v0.1 source profile reproduces the pinned definition.
Consumers can read the [machine-readable errata](docs/rubi-errata.json).
When a rule's file identity, local ID and payload digest match an entry, use
the entry's `replacement` payload (`constraints`, `pattern`, `result`) in
place of the shipped one; `replacement_sha256` is its digest. The digest is the
SHA-256 of the UTF-8 JSON returned by `canonical_payload` in
`scripts/check_duplicate_rules.py`: an object with keys `constraints`,
`pattern`, `result` sorted recursively, compact separators and literal
Unicode. A changed digest calls for review. The shipped rule files keep the
source text, so the converter output stays reproducible.

Take real constants `a=b=c=d=f=m=1`, `e=0`, `p=2`, and `n=1/2`.
All parameters are independent of x and n is nonintegral. On a neighborhood
of π/2 the cosecant is positive, so the extracted prefactor is identically
one. The input integrand at π/2 is
`(1+csc(x)) sqrt(csc(x)^2) = 2`. The claimed antiderivative has derivative
`(1+cos(x)) cos(x) = 0` there. No additive integration constant can repair
the identity. The executable witness reads the shipped rule in
`scripts/test_rubi_errata.py`. The replacement uses cosecants in the residual
integrand, as the sec twin at line 50 does with secants: the extracted factor
`c^IntPart[n] (c (d Csc[e + f x])^p)^FracPart[n] / (d Csc[e + f x])^(p FracPart[n])`
times `(d Csc[e + f x])^(n p)` is `(c (d Csc[e + f x])^p)^n`, and the factor is
locally constant where it is defined. The same test checks that the replacement
residual equals the integrand at the witness, where the factor is one and has
derivative zero.

Lean 4.35.0 checks the same disagreement for any differentiable residual
primitive with the stated derivative. The proof establishes prefactor
equality in a neighborhood and uses uniqueness of the derivative.
[Lean theorem and parameter specialization](https://github.com/OpenSymbolicRules/Lean/blob/ef5044bc9435e75da7e6320a7cf73946d18e2698/OSRTest/RubiCosecant.lean).

[Issue and original report](https://github.com/OpenSymbolicRules/Integration/issues/11) ·
[Pinned RUBI definition](https://github.com/RuleBasedIntegration/Rubi/blob/61e9c18ea248061cd83c67882f7c91a73cef912d/Rubi/IntegrationRules/4%20Trig%20functions/4.5%20Secant/4.5.2.1%20(a%2Bb%20sec)%5Em%20(c%2Bd%20sec)%5En.m#L51)

## RUBI 8.1 line 55, 8.2 line 56, 8.4 line 32 and 8.5 line 32: missing residual integral

At revision `61e9c18ea248061cd83c67882f7c91a73cef912d` (OSR compatibility
rules 8.1 #52, 8.2 #53, 8.4 #27 and 8.5 #27) and in the 4.17.3.0 release
`f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4` (cells 52, 53, 29 and 29), the
rule for `Int[F[d (a + b Log[c x^n])]/x, x]` returns
`1/n Subst[F[d (a + b x)], x, Log[c x^n]]`. The substitution `u = Log[c x^n]`
leaves an integral, `1/n Subst[Int[F[d (a + b x)], x], x, Log[c x^n]]`; the
source drops the `Int`. John Verzani reported it in
[issue #12](https://github.com/OpenSymbolicRules/Integration/issues/12) from
SymJOSR.jl: with `F = Erf`, `a = 0` and `b = c = d = n = 1`, the integrand is
0 at `x = 1` while the derivative of the returned expression is `2/√π`.
In 8.4 and 8.5 the condition also reads `MemberQ[{SinIntegral, CosIntegral}, x]`
(resp. `{SinhIntegral, CoshIntegral}`), which never holds; the corrected rule
tests `F`. The [machine-readable errata](docs/rubi-errata.json) give the
replacements; `scripts/test_rubi_errata.py` evaluates the witness and checks
the corrected chain rule at three points (with `Erf` standing in for `F`, the
identity being independent of `F`).
[8.1 line 55](https://github.com/RuleBasedIntegration/Rubi/blob/61e9c18ea248061cd83c67882f7c91a73cef912d/Rubi/IntegrationRules/8%20Special%20functions/8.1%20Error%20functions.m#L55)

## RUBI 8.1 line 72 and 3.3 line 46: proportionality condition

The rules for `Int[(g + h x)^m F[f (a + b Log[c (d + e x)^n])], x]` (8.1 line
72, compatibility rule 8.1 #69, release cell 69) and
`Int[Log[f (g + h x)^m] (a + b Log[c (d + e x)^n])^p, x]` (3.3 line 46,
compatibility rule 3.3 #33, release cell 43) substitute `u = d + e x` and
write `g + h x` as `g u/d`. That holds only when `e g - d h = 0`, but both
sources test `EqQ[e*f - d*g, 0]`, where `f` is another coefficient of the
integrand; 8.1 line 72 also omits `h` from `FreeQ`. The 8.6 Gamma twin of the
first rule (line 28) states `FreeQ[{..., h, ...}, x] && EqQ[e*g - d*h, 0]`.
With `d = 2`, `e = 3`, `f = 2`, `g = 3` and `h = 1` the source condition holds
and the rewrite is false; `scripts/test_rubi_errata.py` checks this and that
the corrected condition makes the rewrite an identity.
[8.1 line 72](https://github.com/RuleBasedIntegration/Rubi/blob/61e9c18ea248061cd83c67882f7c91a73cef912d/Rubi/IntegrationRules/8%20Special%20functions/8.1%20Error%20functions.m#L72) ·
[3.3 line 46](https://github.com/RuleBasedIntegration/Rubi/blob/61e9c18ea248061cd83c67882f7c91a73cef912d/Rubi/IntegrationRules/3%20Logarithms/3.3%20u%20(a%2Bb%20log(c%20(d%2Be%20x)%5En))%5Ep.m#L46) ·
[8.6 line 28](https://github.com/RuleBasedIntegration/Rubi/blob/61e9c18ea248061cd83c67882f7c91a73cef912d/Rubi/IntegrationRules/8%20Special%20functions/8.6%20Gamma%20functions.m#L28)

## OpenMath hypergeo2, version 0 revision 3, hankel2 formal property

The dictionary's hankel2 description and commented property specify the second-kind function. The formal property places hankel1 on the left of the equation defining J − iY. Its hankel1 entry already gives J + iY. A translator which imports both formal properties would identify the two functions. Keep the family under review before binding the CAS rules to this vocabulary. [Dictionary XML](https://openmath.org/cd/hypergeo2.ocd) · [Rendered hankel2 entry](https://openmath.org/cd/hypergeo2.html#hankel2)

## OSR v0.1 and OpenMath transc2 version 2 revision 1, two-argument arctangent

The specification's single `Atan` row lists arities one and two with the unary OpenMath symbol. The experimental transc2 dictionary defines the binary symbol. Its description and formal properties order the operands horizontal then vertical, while several commented properties print them in reverse order. Two formal properties about the horizontal axis also disagree with the dictionary description. For x=1 and y=0, the description gives angle zero, whereas the XML implication for Re(y)=0 and Re(x)>0 uses `relation1#lt` and requires a strictly negative real part. For x=−1 and y=0 the description gives π, whereas the corresponding implication requires a real part strictly below π. Implement the reviewed real principal angle and treat those FMPs as unsuitable rewrite rules. On the positive vertical axis the correct result is π/2. A host whose `atan2` takes the vertical coordinate first writes this input `atan2(1,0)`. The OSR axis-angle supplement uses `Atan2(0,1)`. [Affected Rubi exports](docs/axis-angle.md#reading-earlier-rubi-exports) · [Pinned dictionary](https://github.com/OpenMath/CDs/blob/cbf607561e3f90630ce7a57fe9a85f5bc0dfdd3c/cd/experimental/transc2.ocd)

## Rubi 4.17.3.0 section 9.1, cells 16–18

In the official release at `f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4`, these three source rewrites multiply a substitution integral by a/(p+1). Their coefficient guard is a(q+1) = b(p+1). Take a=b=1 and p=q=−1. The equation holds, and the claimed coefficient would have to solve 0·z=1. [Upstream rule definitions](https://github.com/RuleBasedIntegration/Rubi/blob/f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4/Rubi/IntegrationRules/9%20Miscellaneous/9.1%20Derivative%20integration%20rules.m#L120-L140)

Take u(t)=t and evaluate at t=1. Match distinct unary function heads f and g, independent of the integration variable, and interpret them as f(t)=t² and g(t)=t³. For the applicable derivative orders choose m=n=2 and m1=n1=1. The substitution target is identically 1 near that point because both its exponents vanish and its bases are positive. With the expression u=x, the pinned `FunctionOfQ[1,x,x]` passes. Its first test `FreeQ[x,x]` is false and its next test `AtomQ[1]` is true. [Rubi predicate definition](https://github.com/RuleBasedIntegration/Rubi/blob/f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4/Rubi/IntegrationUtilityFunctions.m#L4430-L4437)

| Source cell | Bases raised to p and q | Input integrand at t=1 | Requested coefficient |
|---|---|---:|---|
| 16 | f and g | 5 | 1/0 |
| 17 | f′ and g | 4 | 1/0 |
| 18 | f′ and g′ | 3 | 1/0 |

This witness concerns the isolated source rewrites. Whether a complete Rubi evaluation reaches them depends on dispatch and prior simplification. A guard p ≠ −1 is necessary for the displayed coefficient. The other cases and sufficient domain conditions require separate review.

Run `julia --project=converter converter/test/source_edition.jl vendor/Rubi` with the release commit available in that checkout. The test parses all three archived source cells, evaluates their inputs, checks the source conditions, and inspects the pinned predicate definition. Lean proves that the coefficient equation admits parameters for which the required finite quotient cannot exist. [Lean obstruction](verification/RubiSubstitutionDomain.lean) · [Source coverage ledger](editions/rubi-4.17.3.0/coverage.json)

## Undefined exponential helpers in the Rubi 4.17.3.0 maintenance tree

At maintenance revision `61e9c18ea248061cd83c67882f7c91a73cef912d`, the
runtime files for sections 2.1 and 2.3 call `NormalizePowerOfLinear`,
`PowerOfLinearQ` and `PowerOfLinearMatchQ`. Searching the pinned `Rubi/`
tree finds these names only in the rule files, including the normalization
steps at source lines 18 and 10 respectively. OSR preserves the calls and
declares the unresolved helpers in the compatibility manifest. A host lacking
their semantics must decline the affected rules.

## Rubi 4.17.3.0 section 9.1, cells 3, 6 and 7

At release `f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4`, the negative-order
recurrences test `ILtQ[n,0]` and scalar independence. Cell 3 divides by
`b*p*Log[F]`, and cells 6 and 7 divide by `b`. The guards allow zero slope.
The [specializations with finite integrands](docs/derivative-cell-review.md)
and [Lean reciprocal witness](verification/RubiSubstitutionDomain.lean)
concern the isolated rewrites. Matcher precedence and prior simplification
affect whether the engine reaches a particular instance.
