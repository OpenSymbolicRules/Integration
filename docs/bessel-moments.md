# Bessel and Hankel integration moments

Enable the [supplement manifest](../supplements/bessel/rules/meta.json) to apply six integrations from SymbolicIntegration.jl. The [Rubi 4.17.3.0 loader](https://github.com/RuleBasedIntegration/Rubi/blob/f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4/Rubi/Rubi.m#L352) comments out its Bessel section. The file present in the release contains three active definitions for unweighted Bessel J with an affine argument. The supplement handles powers of x multiplying functions of ax. [Released source file](https://github.com/RuleBasedIntegration/Rubi/blob/f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4/Rubi/IntegrationRules/8%20Special%20functions/8.10%20Bessel%20functions.m) · [Pinned CAS rules](https://github.com/JuliaSymbolics/SymbolicIntegration.jl/blob/3625e0e4bb1d78c0ce0acc038d75043aa48efdf1/src/methods/rule_based/rules2/8%20Special%20functions/8.1%20Bessel%20functions.jl)

## Rule and domain

Write $F_ν$ for $J_ν$, $Y_ν$ or first-kind Hankel $H^{(1)}_ν=J_ν+iY_ν$. The variable x ranges over a positive real interval, the scale a is positive real and the parameters a, m and ν are independent of x. On this domain the real logarithm of x fixes the value of $x^m$ even for complex m. The scale condition keeps the function argument on the positive real axis. Supply both inequalities in the CAS assumption context before applying a rule. The upstream source tests a for nonzero. OSR deliberately publishes the narrower domain. [DLMF definitions and branches](https://dlmf.nist.gov/10.2) · [DLMF derivative recurrence](https://dlmf.nist.gov/10.6)

Set $d=m-ν-1$. Differentiating the leading term gives

$$
\frac{d}{dx}\left(\frac{x^m F_{ν+1}(ax)}{a}\right)
= x^m F_ν(ax) + \frac{d}{a} x^{m-1} F_{ν+1}(ax).
$$

| Condition | Oriented rewrite of the indefinite integral of $x^m F_ν(ax)$ |
|---|---|
| $d=0$ | Return $x^m F_m(ax)/a$. |
| d is a positive even integer | Return $x^m F_{ν+1}(ax)/a$ minus $d/a$ times the integral of $x^{m-1} F_{ν+1}(ax)$. |

Each reduction changes the exponent and order to m−1 and ν+1, so d decreases by two. Starting from $d=2k$ takes k reductions and one direct application. A host must establish the integer and parity predicates before introducing the residual integral. The primitives are local up to an additive constant.

## Vocabulary and coverage

The [rule file](../supplements/bessel/rules/bessel.json) retains the six upstream IDs and records the source revision and locator for each. The OpenMath identifiers come from the experimental hypergeo2 dictionary, version 0 revision 3. Arguments are order first, argument second. Interpret integer-order Y by the standard limiting value. Only the reviewed symbol meanings are used here. The dictionary's formal properties are not imported as rewrite rules. [Pinned content dictionary](https://github.com/OpenMath/CDs/blob/cbf607561e3f90630ce7a57fe9a85f5bc0dfdd3c/contrib/cd/hypergeo2.ocd) · [DLMF second-kind function](https://dlmf.nist.gov/10.2.E3)

| Upstream rule IDs | Decision |
|---|---|
| 8_1_1, 8_1_5 | Include direct and reduction rules for Bessel J. |
| 8_1_2, 8_1_6 | Include both rules for Bessel Y. |
| 8_1_9, 8_1_11 | Include both rules for first-kind Hankel. |
| 8_1_3, 8_1_4, 8_1_7, 8_1_8 | Hold modified Bessel I and K. OSR v0.1 names these functions, but the reviewed OpenMath catalogue supplies no corresponding named symbol. |
| 8_1_10, 8_1_12 | Hold second-kind Hankel. The formal property in its OpenMath entry names first-kind Hankel on the left, contradicting the accompanying text. [Recorded vocabulary discrepancy](../upstream-bugs.md) |

## Verification

The [nine fixtures](../supplements/bessel/tests/moments.json) exercise one, two and three applications per function at order ½. The [test context](../supplements/bessel/test-context.json) supplies the assumption x > 0 for all nine. Their step counts measure this supplement. Run `just test` to evaluate the actual rules, check the decreasing index and compare differentiated reference primitives on the positive real interval. The half-integer numerical oracle uses the elementary sine and cosine forms; both components of the complex Hankel result are checked. The guard tests exercise zero, negative or unknown scales and arguments, variable-dependent parameters, and unsuitable recurrence indices. [Elementary half-integer formulas](https://dlmf.nist.gov/10.16) · [Pinned upstream examples](https://github.com/JuliaSymbolics/SymbolicIntegration.jl/blob/3625e0e4bb1d78c0ce0acc038d75043aa48efdf1/test/methods/rule_based/test_special_functions.jl)

A separate numerical check with mpmath 1.3.0 differentiated the serialized right-hand sides at orders 0, −0.7 and 1.25, using 45 decimal digits, (a, x) = (0.7, 0.8) and (2.25, 1.3), and a central difference of step 10⁻¹⁰. The residual integral was evaluated by quadrature from 0.6 to x. All 54 checks passed with absolute error below 10⁻¹⁵. All six rules have formal verification status **unproved**. [Upstream MIT license](../supplements/bessel/LICENSE)
