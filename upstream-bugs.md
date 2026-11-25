# Upstream bugs

## RUBI 4.5.2.1, source line 51, OSR rule 47

The [released 4.17.3.0 edition](docs/rubi-release.md) contains the same residual at source cell 48, with an operational Star product. It has a separate fingerprint and skip record.

John Verzani reported a mismatch between the integrand and the residual
integral in RUBI revision `61e9c18ea248061cd83c67882f7c91a73cef912d`
(the pinned loader declares 4.17.3.0). The pattern contains inert cosecant,
the prefactor contains active cosecant, and the residual integral contains
two cosines. The v0.1 source profile reproduces the pinned definition.
Consumers can read the [machine-readable errata](docs/rubi-errata.json).
Skip a rule when its file identity, local ID and payload digest match an
entry marked `skip`. The digest is the SHA-256 of the UTF-8 JSON returned by
`canonical_payload` in `scripts/check_duplicate_rules.py`: an object with
keys `constraints`, `pattern`, `result` sorted recursively, compact
separators and literal Unicode. A changed digest calls for review.

Take real constants `a=b=c=d=f=m=1`, `e=0`, `p=2`, and `n=1/2`.
All parameters are independent of x and n is nonintegral. On a neighborhood
of π/2 the cosecant is positive, so the extracted prefactor is identically
one. The input integrand at π/2 is
`(1+csc(x)) sqrt(csc(x)^2) = 2`. The claimed antiderivative has derivative
`(1+cos(x)) cos(x) = 0` there. No additive integration constant can repair
the identity. The executable witness reads the shipped rule in
`scripts/test_rubi_errata.py`. A replacement involving cosecants would need
its own branch conditions and verification.

Lean 4.35.0 checks the same disagreement for any differentiable residual
primitive with the stated derivative. The proof establishes prefactor
equality in a neighborhood and uses uniqueness of the derivative.
[Lean theorem and parameter specialization](https://github.com/OpenSymbolicRules/Lean/blob/ef5044bc9435e75da7e6320a7cf73946d18e2698/OSRTest/RubiCosecant.lean).

[Issue and original report](https://github.com/OpenSymbolicRules/Integration/issues/11) ·
[Pinned RUBI definition](https://github.com/RuleBasedIntegration/Rubi/blob/61e9c18ea248061cd83c67882f7c91a73cef912d/Rubi/IntegrationRules/4%20Trig%20functions/4.5%20Secant/4.5.2.1%20(a%2Bb%20sec)%5Em%20(c%2Bd%20sec)%5En.m#L51)

## OpenMath hypergeo2, version 0 revision 3, hankel2 formal property

The dictionary's hankel2 description and commented property specify the second-kind function. The formal property places hankel1 on the left of the equation defining J − iY. Its hankel1 entry already gives J + iY. A translator which imports both formal properties would identify the two functions. Keep the family under review before binding the CAS rules to this vocabulary. [Dictionary XML](https://openmath.org/cd/hypergeo2.ocd) · [Rendered hankel2 entry](https://openmath.org/cd/hypergeo2.html#hankel2)

## OSR v0.1 and OpenMath transc2 version 2 revision 1, two-argument arctangent

The specification's single `Atan` row lists arities one and two with the unary OpenMath symbol. The experimental transc2 dictionary defines the binary symbol. Its description and formal properties order the operands horizontal then vertical, while several commented properties print them in reverse order. On the positive vertical axis the correct result is π/2. In the Maxima calling convention this input is `atan2(1,0)`. The OSR angle supplement uses `Atan2(0,1)`. [Affected Rubi exports](docs/maxima-branches.md#reading-earlier-rubi-exports) · [Pinned dictionary](https://github.com/OpenMath/CDs/blob/cbf607561e3f90630ce7a57fe9a85f5bc0dfdd3c/cd/experimental/transc2.ocd)
