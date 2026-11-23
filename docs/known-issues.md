# Known Issues in the Converted RUBI Corpus

Defects of the conversion itself, as opposed to the RUBI source. Each entry
states how it was measured so that it can be re-measured after a fix.

Measured against: this repository at 6,257 rules in 188 rule files, converted
from Rubi 4.16.1; `OpenSymbolicRules.jl` 0.1.0; Julia 1.13.0.

## 1. The integration variable is lost — fixed

**What happened.** RUBI writes an integration rule as
`Int[integrand, x_Symbol] := antiderivative /; conditions`. The converter kept
the integrand as the rule's `pattern` and dropped the `Int[..., x_Symbol]`
wrapper. Two things went with it: the binding of the integration variable, so
254 rules named an `x` their pattern never bound; and the `x_Symbol`
restriction, so a rule matched integrands it was never meant to. Rule
`1.1.1.1:2`, `x_^m_. => x^(m+1)/(m+1)`, matched the constant integrand `-2` and
returned `(-2)^2/2`.

**Effect, measured.** Over section 1.1.1 — 906 test problems against the 186
rules of that section:

| | verified | closed form | unevaluated | unchanged | error |
| --- | --- | --- | --- | --- | --- |
| before | 0 | 903 | 0 | 1 | 2 |
| after | 4 | 19 | 118 | 748 | 17 |

The rule set used to answer almost every problem and answer none of them
correctly. It now leaves unevaluated or unchanged what it cannot solve, and
reaches the recorded antiderivative for four problems. Those 903 closed forms
were wrong answers, not answers the fix lost.

**What changed.** The pattern is the whole application,
`["Int", <integrand>, "x_symbol"]`. `map_wildcard` no longer drops a `Symbol`
type head, which the specification can now express (OSR-W-003). All 6,257 rules
carry the wrapper, and the rules naming a name their pattern never bound fall
from 357 to 50.

**How to reproduce.** `cd ../OpenSymbolicRules.jl && just conformance 1.1.1`

## 2. Fifty rules still name something their pattern never bound

50 of 6,257 rules — 0.8%, down from 357 — reference a lowercase name in their
result or constraints that nothing binds, most often `m`, `f`, `d`, or `n`. A
further three are RUBI `Module[{aa, bb}, ...]` locals, which are bound by the
`Module` rather than free; the OSR format has no scoping construct for those, so
a host cannot tell them apart from a free name. The remainder have not been
characterised.

A host must supply a global symbol of that name for such a rule to apply, which
is the same defect as issue 1 on a smaller scale.

## 3. Empty rule files

33 of the 222 rule files carry `"rules": []`. They correspond to RUBI sections
the converter produced no rules for. The section is declared in `meta.json` and
in the file, so a loader sees a section that contributes nothing.

**Investigation and partial parser fix.** At Integration commit `779c9f9`,
the pinned RUBI source is commit `61e9c18ea248061cd83c67882f7c91a73cef912d`.
Its `Rubi/PacletInfo.m` identifies version `4.17.3.0`, although the existing
manifest and historical per-rule provenance say `4.16.1`. The original
conversion must be audited before relabelling the published corpus.

The converter had assumed that every definition fits on one line. It now
parses complete notebook `::Code::` cells and rejects unconsumed cell text.
For example, section 1.4.2 contains 29 definitions; a local conversion
produced 29 schema-valid candidate rules with no conversion warnings. These
are not yet published in `rules/`, and no formal verification is implied.

This is **not a complete fix**: other files contain local `With` bindings or
RUBI's evaluation-aware `Star` operator. The parser retains both constructs,
but files using either are not exported until binding and operational
semantics are reviewed; unsupported cells produce diagnostics rather than a
silently partial converted file. In an exploratory scan of notebook cells at
this pin, 1,208 of 1,212 candidate `Int` cells parsed individually and four
failed (derivative notation or `=!=`); these are parser counts, not verified
or published rules; candidates are cells beginning with `Int[` after leading
whitespace. Of the parsed cells, 894 contain `Star` and 273 contain a
local binding; these groups can overlap. A full conversion remains blocked and
does not change the output tree when any file reports a warning.
Reproduce the cell-level JSON report with
`julia --project=converter converter/scripts/audit-cells.jl vendor/Rubi`.
See the [translation proposal](rubi-translation-proposal.md) for the pending
semantic and ordering decisions.

## 4. Mathematical constants converted as free names

**What happens.** `E`, `ImaginaryI` and `Pi` are Mathematica constants (the
base of the natural logarithm, the imaginary unit, π). The converter writes
them as bare names and gives them no entry in the file's `semantics` block,
so a host reads them as free variables, like the names of issue 2.

**Measured.** With `scripts/inventory_v1.py` (`rules_by_unbound_atom`) on this
repository at 6,257 rules: 630 rules use at least one of them, `E` in 437,
`ImaginaryI` in 275 and `Pi` in 136. The same script counts 739 rules with an
atom their pattern does not bind; the other 109 are the names of issue 2 and
RUBI locals.

**Consequence for OSR v1.** The inventory excludes these rules from the
migration candidates: their OpenMath counterparts (`nums1#e`, `nums1#i`,
`nums1#pi`) would have to be declared by the converter, and `nums1#e` and
`nums1#i` added to the registry of OpenSymbolicRules/OpenMath, before such a
rule can be stated in Lean.
