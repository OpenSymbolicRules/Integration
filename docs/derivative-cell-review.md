# Rubi 4.17.3.0 derivative rules

Both pinned editions use identical source bytes for section 9.1 (SHA-256
`2087d3e21da88eaccb5d73b44d63c9071a56405df7fd0bbe320cc839213774df`).
The table reviews the 15 source cells outside the original six-rule export.
Cell numbers refer to the upstream notebook. [Source](https://github.com/RuleBasedIntegration/Rubi/blob/f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4/Rubi/IntegrationRules/9%20Miscellaneous/9.1%20Derivative%20integration%20rules.m)

### Reading the real theorems

Write F and G for the indicated functions at the original variable, with
their indicated derivatives F′ and G′. In substitutions let Z be the new
variable, assume the source multiplier u factors as K(Z) on the branch
of interest, and let P be a primitive of K at Z(x). The proofs differentiate
the proposed multiple of P(Z(x)). They use the actual coefficients, signs
and powers from the source. They require differentiability at the evaluation
point and, for arbitrary real powers, positivity of the bases used there.
A CAS must justify the factorization and the chosen branch on its domain.
Rubi's `FunctionOfQ[Z,u,x]` tests functional dependence, `SubstFor[Z,u,x]`
constructs the new integrand, `SimplifyIntegrand` processes it, and `Subst`
returns to the original variable after integration. Their evaluation order
and variable binding are part of the transcription. [Pinned Rubi utilities](https://github.com/RuleBasedIntegration/Rubi/blob/f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4/Rubi/IntegrationUtilityFunctions.m)

| Cell | Source operation | Real interpretation and conditions beyond matching | Lean theorem in OSR.Rubi |
|---:|---|---|---|
| 1 | Integrate order n to order n−1 | For positive integer n and f locally of class Cⁿ. The source only tests independence of n from x. | predecessorDeriv |
| 3 | Exponential integration by parts for negative n | V is the chosen order-n primitive, V′ is its successor. Positive c,F and nonzero b p log(F) suffice. | exponentialPrimitiveParts |
| 6 | Sine integration by parts for negative n | A compatible primitive pair and b ≠ 0. Cosine residual has a plus sign. | sinePrimitiveParts |
| 7 | Cosine integration by parts for negative n | A compatible primitive pair and b ≠ 0. Sine residual has a minus sign. | cosinePrimitiveParts |
| 8 | Substitute Z = Dⁿ⁻¹f | Positive integer n gives Z′ = Dⁿf for sufficiently smooth f. | primitiveSubstitution, predecessorDeriv |
| 9 | Z = fg | Ordinary first derivatives. The primitive is a P(Z). | productSubstitution |
| 10 | Z = (Dᵐ⁻¹f)g | Positive integer m suffices. Retain the equality m1 = m−1. | productSubstitution, predecessorDeriv |
| 11 | Z = (Dᵐ⁻¹f)(Dⁿ⁻¹g) | Positive integers m,n suffice. Both predecessor equalities are required. | productSubstitution, predecessorDeriv |
| 12 | Z = f^(p+1) g | f(x) > 0 is sufficient for real powers. With a = b(p+1) the outside coefficient is b, including at p = −1. | leftPowerSubstitution |
| 13 | Z = F^(p+1) g, F = Dᵐ⁻¹f | As cell 12 with positive integer m, F(x) > 0, and the source predecessor equality. | leftPowerSubstitution, predecessorDeriv |
| 14 | Z = F g^(q+1), F = Dᵐ⁻¹f | Positive integer m, g(x) > 0, b = a(q+1). The outside coefficient is a. | rightPowerSubstitution, predecessorDeriv |
| 15 | Z = F^(p+1) G, F = Dᵐ⁻¹f, G = Dⁿ⁻¹g | As cell 13 with both predecessor orders and F(x) > 0. | leftPowerSubstitution, predecessorDeriv |
| 16 | Z = f^(p+1) g^(q+1) | Both bases positive, a(q+1) = b(p+1), and **p+1 ≠ 0**. | twoPowerSubstitution |
| 17 | Same two powers with F = Dᵐ⁻¹f | Cell 16 conditions, positive integer m and its predecessor equality. | twoPowerSubstitution, predecessorDeriv |
| 18 | Same two powers with F = Dᵐ⁻¹f, G = Dⁿ⁻¹g | Cell 16 conditions, positive integer m,n and both predecessor equalities. | twoPowerSubstitution, predecessorDeriv |

For a negative order n, a CAS needs a convention for repeated integration
and the constants of integration. For example a tower V₀=f, V₁,V₂,… may
be chosen on an interval with V′ⱼ₊₁=Vⱼ. At n=−1 this gives V′₁=f. Cells
3, 6 and 7 need this adjacent-member relationship and a primitive of the
residual integrand. Their proofs work for any such choices. The source
`ILtQ[n,0]` establishes a negative integer. It supplies neither the tower
nor the required nonzero divisor. A real theorem about this interpretation
does not assign an OpenMath iterated-derivative meaning to arbitrary negative
or symbolic Wolfram orders. [Wolfram Derivative](https://reference.wolfram.com/language/ref/Derivative.html) · [OpenMath calculus1](https://openmath.org/cd/calculus1.html#nthdiff)

### Two failures of the published guards

* Cells 3, 6 and 7 admit n = −1 and b = 0 under their listed scalar guards.
  Take V(t)=t, V′=1 and x=1. The sine weight at a=π/2, the cosine weight
  at a=0, and the exponential weight at c=1,F=2,p=1,a=0 all give a finite
  integrand there. The right sides request 1/b or 1/(b p log(F)).
  `primitiveSlopeCounterexample` proves the nonexistence of those reciprocals
  at that specialization. A CAS may simplify a constant weight before matching.
* In cells 16–18 take a=b=1 and p=q=−1. The coefficient equality holds while
  the quotient a/(p+1) has no real value. The source guard and input integrand
  are evaluated in the [existing witness](../upstream-bugs.md).
  `substitutionCoefficientCounterexample` checks the denominator obstruction.

The proofs are local real statements. Formal verification of Rubi's matcher,
the implementation of its substitution helpers and a complex branch model
remain separate tasks. [Recurrences](../verification/RubiDerivativeRecurrences.lean) · [Substitutions](../verification/RubiDerivativeSubstitutions.lean) · [Counterexamples](../verification/RubiSubstitutionDomain.lean)
