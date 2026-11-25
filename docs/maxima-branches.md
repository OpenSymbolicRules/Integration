# Maxima integration on real intervals

Enable the [Maxima supplement](../supplements/maxima/rules/meta.json) to integrate angles on the vertical axis. In Maxima 5.50post, replacing `atan2(y,0)` with an expression containing y/0 caused a division error. The pinned fix instead uses the sign of y. OSR derives two directed integral rules from the first two solved examples in the upstream regression. The other assertions in that change exercise fallback to unevaluated integrals. The upstream distribution terms accompany the supplement. [Maxima fix and test](https://github.com/calyau/maxima/commit/1b81426deabf5f8366ce07aafc581944673a5467) · [COPYING](../supplements/maxima/COPYING)

## Two guarded rules

In this rule file, `Atan(horizontal, vertical)` denotes the principal angle of the point with those coordinates. For real y > 0, `Atan(0,y)` equals π/2. For real y < 0 it equals −π/2. A Maxima or Python adapter must pass the **vertical coordinate first** when calling its native `atan2`. The OSR semantics map binds the two-argument head to `transc2#arctan`. Its description and formal tangent equation give the horizontal-first order. [OpenMath dictionary, version 2 revision 1](https://github.com/OpenMath/CDs/blob/cbf607561e3f90630ce7a57fe9a85f5bc0dfdd3c/cd/experimental/transc2.ocd) · [Maxima source assertions](https://github.com/calyau/maxima/blob/1b81426deabf5f8366ce07aafc581944673a5467/tests/rtest_integrate.mac#L7377-L7383)

| Integrand | Reference primitive | Required interval |
|---|---|---|
| Atan(0, b+x) | π abs(b+x)/2 | b+x has a known strict sign |
| x Atan(0, b+x²) | π abs(b+x²)/4 | b+x² has a known strict sign |

Both x and b are real and b is independent of x. On each admitted interval, differentiating the absolute value multiplies the derivative of its argument by its sign. The two entries are instances of that one chain-rule identity. The upstream examples use offsets 0 and −1 respectively. The supplement generalizes the constant offset and closes the integral in one application. If the sign is unknown or the ordinate is zero, an adapter must decline the rewrite. At the origin `atan2(0,0)` is outside the stated mathematical domain, even if a numerical library returns a value there. The two entries have Lean status **unproved**. [Rule definitions](../supplements/maxima/rules/angles.json) · [One-step cases](../supplements/maxima/tests/angles.json) · [Fixture assumptions](../supplements/maxima/test-context.json)

## Reading earlier Rubi exports

The pinned OSR v0.1 specification lists `Atan` with arity 1–2 and one dictionary symbol, `transc1#arctan`. OpenMath assigns the binary function a different symbol. In the Rubi 4.17.3.0 edition, eight binary calls occur across eight rule entries in three files. All eight are in results. Their release section and local IDs are 4.1.5 (7, 8), 4.1.6 (4, 7, 8, 17, 18) and 4.1.7 (75). The distributed Rubi fixtures contain another 106 binary calls across 69 examples. These are counts of expressions in the source translation and say nothing about the proof status of those entries. For a **Rubi** input adapter, preserve the Wolfram coordinate order of a binary `Atan`. A strict OpenMath consumer encountering a binary application declared with the unary symbol should report the mismatch. A corpus-wide change needs a representation that can distinguish both arities inside a single file while preserving existing rule identities. [Specification §4.5](https://github.com/OpenSymbolicRules/Specification/blob/480f6501816d883f8e53899d469f3737a7d1aa42/docs/spec.md) · [Wolfram ArcTan](https://reference.wolfram.com/language/ref/ArcTan.html)

## Four logarithm regressions

The [test vectors](../supplements/maxima-regressions/examples.json) transcribe all four assertions added for Maxima bug 5244. Each supplies a source revision, file and line range. Principal complex logarithms and square roots are used where they appear. The independent variable is real throughout. The local domains below are OSR's explicit choices for comparison of primitives up to an additive constant. [Upstream assertions](https://github.com/calyau/maxima/blob/8806ad76963d385137fc8b5198746f98565b3f61/tests/rtest_integrate.mac#L6894-L6906) · [Source distribution terms](../supplements/maxima/COPYING)

| Input | Real intervals covered | What the case detects |
|---|---|---|
| 1/(x+i) | All real x | At x=0 the integrand is −i. Substituting log(abs(x+i)) as the primitive gives derivative zero there. |
| 1/x | x<0 or x>0 | log(abs(x)) supplies a real primitive on both components. |
| 1/(x²−a√(−a)) | Constant a<0, separately x<0 and x>0 | The integrand is smooth at zero. The ratio in the source's principal logarithm reaches its negative-real cut there, so that primitive is compared on each side. |
| 1/(x²−a²) | Real constant a≠0, separately on each interval cut by ±a | The two real logarithms use absolute values. The CAS must keep the poles out of the comparison interval. |

From the repository root, run `python3 supplements/maxima/check.py` or `just test`. The check exercises the serialized guards, both signs of the angle, the complex derivative of the shifted reciprocal and every connected interval in the table. To reproduce the four logarithm trees, save the pinned test file and run `python3 supplements/maxima-regressions/import.py rtest_integrate.mac`. The importer checks the full source SHA-256 before reading the selected assertions. CI compares its output byte for byte with the published JSON. An independent check using SymPy 1.14.0 differentiated the two angle primitives on each sign branch and the four logarithm references on the specified real intervals. The four source assertions carry no Rubi step count.
