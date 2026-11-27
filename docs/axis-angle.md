# Axis-angle integration supplement

The [axis-angle supplement](../supplements/axis-angle/rules/meta.json) integrates the principal angle of a point on the vertical axis. It is written for this repository and distributed under the MIT license, like the rest of it. Enable it after the released Rubi rules; its rule identity is `osr-supplement:axis-angle`.

## Two guarded rules

`Atan2(horizontal, vertical)` denotes the principal angle of the point with those coordinates. On the vertical axis the horizontal coordinate is 0, and for a real vertical coordinate u the angle is π/2 when u > 0 and −π/2 when u < 0. A host whose native `atan2` takes the vertical coordinate first must swap the operands.

| Integrand | Primitive | Guard |
|---|---|---|
| Atan2(0, a x + b) | π abs(a x + b) / (2a) | a ≠ 0, and a x + b has a known strict sign |
| x Atan2(0, a x² + b) | π abs(a x² + b) / (4a) | a ≠ 0, and a x² + b has a known strict sign |

The variable x and the constants a and b are real, and a and b do not depend on x. Both rules follow from one identity: away from u = 0, the derivative of abs(u) is sign(u) times the derivative of u, so the derivative of π abs(u)/2 is u′ times the angle of (0, u). Dividing by u′ = a, or by u′/x = 2a, gives the two primitives. When the sign of the vertical coordinate is unknown, or it vanishes on the interval, a rule does not apply: abs(u) has no derivative where u = 0.

The [examples](../supplements/axis-angle/tests/angles.json) apply each rule once: rule 1 with a = 2, b = −5, and rule 2 with a = −1, b = 3.

## Lean evidence for the real rules

| v0.1 rule ID | Lean theorem | Statement at the evaluation point x |
|---|---|---|
| `osr-supplement:axis-angle:1` | `OSR.AxisAngle.affine` | For a ≠ 0, the derivative of π abs(b + a t)/(2a) at x equals the principal angle of (0, b + a x). |
| `osr-supplement:axis-angle:2` | `OSR.AxisAngle.quadratic` | For a ≠ 0, the derivative of π abs(b + a t²)/(4a) at x equals x times the principal angle of (0, b + a x²). |

Each theorem takes the rule's strict sign guard on the vertical coordinate as a hypothesis. The [proofs](../supplements/axis-angle/AxisAngle.lean) use Mathlib's `Complex.arg` on a point with real part zero, and the derivatives of the absolute value on either side of zero. Each theorem is checked to depend only on the standard axioms.

Run `just axis-angle-lean /path/to/prepared/Lean` with the OSR Lean project or a prepared Mathlib checkout. The replay reads the Lean and Mathlib pins from the published Integration report, runs [`check.py`](../supplements/axis-angle/check.py), and compiles the proofs with warnings treated as errors. `check.py` (also run by `just test`) compares the serialized patterns, guards, results and theorem names with these statements, and differentiates both primitives numerically on every sign interval of the vertical coordinate.

## Reading earlier Rubi exports

The Rubi release, compatibility profile and axis-angle supplement declare the binary head `Atan2` in their v0.1 extension manifests. A file can now use both `["Atan", t]` for `transc1#arctan` and `["Atan2", x, y]` for `transc2#arctan`. The latter preserves the Wolfram source operand order. For example, the point (−1, 0) gives π and (0, −1) gives −π/2. Use this OpenMath interpretation for real coordinates away from the origin. A source-aware host can evaluate complex operands if it implements the Wolfram branch convention. Otherwise preserve the symbolic call. In section 6.7.1, 29 of the 106 binary calls contain an explicit imaginary unit in their vertical coordinate, spread across 19 fixtures. For example, a positive real c makes −ic purely imaginary. Feeding that coordinate to a real numerical `atan2` would lose information. [Release manifest](../editions/rubi-4.17.3.0/rules/meta.json) · [Wolfram ArcTan](https://reference.wolfram.com/language/ref/ArcTan.html)

When importing an older Rubi snapshot, recognize the old binary `["Atan", x, y]` by arity and preserve both operands in order. The v1 faithfulness checker rejects a binary application bound to the unary dictionary symbol, or a unary application bound to the binary symbol. The affected Rubi 4.17.3.0 results have section and local IDs 4.1.5 (7, 8), 4.1.6 (4, 7, 8, 17, 18) and 4.1.7 (75). The compatibility profile has its own stable local IDs. In the test suite the migration updates 106 calls in 69 cases. Frozen benchmark selections can retain their case IDs and update their JSON hashes when adopting this conversion. The pinned specification lists both arities in a single core entry. The Integration extension uses its existing manifest mechanism. [Earlier snapshot](https://github.com/OpenSymbolicRules/Integration/tree/f9cd8848b7930abe13ab32752ec0b2cab432e5af) · [Specification](https://github.com/OpenSymbolicRules/Specification/blob/480f6501816d883f8e53899d469f3737a7d1aa42/docs/spec.md)
