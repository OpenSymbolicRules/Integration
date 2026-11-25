# Upstream bugs

## RUBI 4.5.2.1, source line 51, OSR rule 47

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
