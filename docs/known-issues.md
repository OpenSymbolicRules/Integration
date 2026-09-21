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
