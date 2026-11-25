# Open-source integration work after Rubi 4.17.3.0

Use the [released Rubi profile](rubi-release.md) as the reference. A supplement has its own identity and priority. Consumers can enable it after the released rules. Keep its applications and test results identifiable in a trace. This survey covers the following specific upstream contributions.

| Source and change examined | Decision |
|---|---|
| [SymbolicIntegration.jl special-function implementation and tests](https://github.com/JuliaSymbolics/SymbolicIntegration.jl/commit/03cbe3cbbaa08d358a635ed8706d9e8f5553f87e) | Include four Airy rules and six one-step examples. No Airy head appeared in the released rule sources or the distributed OSR tests. |
| [SymPy manualintegrate rules and regression tests](https://github.com/sympy/sympy/commit/6856a0953eb7269e094a7755a8151d684bcb879c) | Include six integration problems with reference primitives. None of the six input trees occurred among the 72,523 distributed examples after sorting scalar sum and product operands. Product-to-sum and completing the square already have mathematical precedents. The new inputs exercise their composition. |
| [Symja Rubi port](https://github.com/axkr/symja_android_library/commit/a252ce6f52dbcd7709cfa3949fcf57bcd6aa716c) and [later independent test fixes](https://github.com/axkr/symja_android_library/commit/2b1c641d11fe30ac1ac1bfb1c6cf2406ee8bb8f5) | The generated port overlaps Rubi. The later changes include dispatch, unsupported substitutions and evaluation of RootSum. These supply engine regression candidates. No portable additional identity was established from these changes. |
| [SageMath Giac backend doctest](https://github.com/sagemath/sagemath-giac/blob/e48e1efb98accafd4b263780b45d30fbf1b37f44/README.rst) | Include a real minimum whose primitive is differentiable at the branch boundary. |
| [REDUCE limit on work in tidysqrt](https://github.com/reduce-algebra/reduce-algebra/commit/0854f708afc39297d045744c175360c5c315c5c2) | A resource limit belongs in an engine benchmark with a budget. |
| [Maxima assumption-dependent integration tests](https://github.com/calyau/maxima/commit/f6fd0a9266cbe0c71921ae8eaf35804b64c9b37b) | Record the need to supply the assumptions Maxima obtains interactively. Import requires an explicit portable guard and a branch-aware reference. |

## Airy rules

The [supplement manifest](../supplements/airy/rules/meta.json) references four directed integrations. For either standard Airy solution F = Ai or Bi, integrate F′(a + bx) to F(a + bx)/b when a and b are independent of x and b is nonzero. If a guard is false or unknown, decline the rewrite. Integrate x F(x) to F′(x) by the equation F″(x) = x F(x). Both solutions are entire. The statements are valid over real or complex arguments, up to an additive constant. The experimental OpenMath Airy dictionary specifies the derivative order as the first operand of Ai2 and Bi2. [Pinned CAS implementation](https://github.com/JuliaSymbolics/SymbolicIntegration.jl/blob/3625e0e4bb1d78c0ce0acc038d75043aa48efdf1/src/methods/rule_based/rules2/8%20Special%20functions/8.2%20Airy%20functions.jl) · [OpenMath airy](https://openmath.org/cd/airy.html) · [DLMF §9.2](https://dlmf.nist.gov/9.2)

The [six OSR fixtures](../supplements/airy/tests/airy.json) cover both signs of the affine slope and both first moments. Each records one direct application of the supplement. Rubi supplied no step count for them. The import retains the [upstream MIT notice](../supplements/airy/LICENSE).

The same CAS also has Hankel moments and recursive reductions. They require a consistent choice of branch for powers and Hankel functions, and a decreasing recurrence for termination. OpenMath hypergeo2 version 0 revision 3 contains a discrepancy. The formal property of hankel2 names hankel1 on its left-hand side. The first and second kinds cannot share that definition. The Hankel family remains a candidate pending a reviewed mapping and applicability conditions. [Pinned CAS rules](https://github.com/JuliaSymbolics/SymbolicIntegration.jl/blob/3625e0e4bb1d78c0ce0acc038d75043aa48efdf1/src/methods/rule_based/rules2/8%20Special%20functions/8.1%20Bessel%20functions.jl) · [OpenMath hankel2](https://openmath.org/cd/hypergeo2.html#hankel2) · [DLMF §10.6](https://dlmf.nist.gov/10.6)

## SymPy regressions

The [six examples](../supplements/sympy-regressions/examples.json) contain stable IDs, OSR-Expr integrands, the integration variable and reference primitives. Four pair sine or cosine of x² with sine or cosine of x. Two integrate x times sine or cosine of x²+x. The primitives use the standard Fresnel C and S normalization, with integrands cos(πt²/2) and sin(πt²/2). Product-to-sum followed by completing the square gives primitives equivalent up to a constant. [SymPy source tests](https://github.com/sympy/sympy/blob/6856a0953eb7269e094a7755a8151d684bcb879c/sympy/integrals/tests/test_manual.py) · [DLMF §7.2](https://dlmf.nist.gov/7.2) · [Upstream license](../supplements/sympy-regressions/LICENSE)

These test-only vectors use the existing OSR expression syntax. Their container records source, revision and path. The official v0.1 test-file schema requires an integer step count and SymPy's tests assert a primitive without recording a Rubi trace. Keep these vectors outside that manifest. Benchmarks can identify them by source revision and case ID and compare differentiated outputs.

## SageMath / Giac regression

The [Giac example](../supplements/giac-regressions/examples.json) records the real integral of 2 min(x, 2x). On x < 0 the integrand is 4x and on x ≥ 0 it is 2x. A primitive is (3x² − x|x|)/2. Its derivative at zero exists since the difference quotient tends to zero from either side. Keep the real-domain constraint with the expression. The package records a comparison with Giac without a Rubi step count. This is a post-release regression example, with no claim about when Giac first supported the integral. [Source doctest](https://github.com/sagemath/sagemath-giac/blob/e48e1efb98accafd4b263780b45d30fbf1b37f44/README.rst) · [Source licensing terms](../supplements/giac-regressions/COPYING)

## Checks

Run `just test` to check the rule trees, guards, fixture assignments and numerical derivatives. Airy and Fresnel examples cover three real arguments. The Giac case checks each real branch and their join. The checks use only the Python standard library. Symbolic differentiation was also checked with SymPy 1.14.0 for all four general formulas and the twelve Airy and Fresnel examples. The formal verification status of the four new rules is **unproved**. Promote a supplemental rule to the v1 verification catalogue only after its symbol mapping, hypotheses and theorem agree with the source.
