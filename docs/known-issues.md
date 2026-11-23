# Known Issues in the Converted RUBI Corpus

Defects of the conversion itself, as opposed to the RUBI source. Each entry
states how it was measured so that it can be re-measured after a fix.

Historical measurements below used this repository at 6,257 rules in 188
nonempty rule files, labelled Rubi 4.16.1; `OpenSymbolicRules.jl` 0.1.0;
Julia 1.13.0. The pinned source's own version is 4.17.3.0, as discussed below.

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

At the original measurement, 33 files carried `"rules": []`. The section is
declared in `meta.json` and in the file, so a loader sees a section that
contributes nothing. Section 1.4.2 now has 29 converted rules; it is not a
Lean-certified v1 rule set. Other empty files remain.

**Investigation and partial parser fix.** At Integration commit `779c9f9`,
the pinned RUBI source is commit `61e9c18ea248061cd83c67882f7c91a73cef912d`.
Its `Rubi/PacletInfo.m` identifies version `4.17.3.0`. The root manifest now
records that source version; historical per-rule provenance still says
`4.16.1` and must be audited before those records are relabelled.

The converter had assumed that every definition fits on one line. It now
parses complete notebook `::Code::` cells and rejects unconsumed cell text.
For example, section 1.4.2 contains 29 definitions; a local conversion
produced 29 schema-valid rules with no conversion warnings, now available in
`rules/`; no formal verification is implied. Of these, 26 duplicate rules
also found in an older 1.3.4 file. Both identities are preserved and the
duplicate baseline explicitly records them. That older file is not loaded by
the pinned RUBI default loader; the default OSR manifest now uses source file
order and excludes it. The old manifest's section-sorted order was replaced.

This is **not a complete fix**: other files contain local `With` bindings or
RUBI's evaluation-aware `Star` operator. The parser retains both constructs,
but files using either are not exported until binding and operational
semantics are reviewed; unsupported cells produce diagnostics rather than a
silently partial converted file. In an exploratory scan of notebook cells at
this pin, 1,190 of 1,212 candidate `Int` cells parsed individually and 22
failed (unsupported compound heads, derivative notation or `=!=`); these are parser counts, not verified
or published rules, measured before compound-head parsing was added; candidates are cells beginning with `Int[` after leading
whitespace. Of the parsed cells, 878 contain `Star` and 273 contain a
local binding; these groups can overlap. A full conversion remains blocked and
does not change the output tree when any file reports a warning. At this pin,
the stricter full-corpus probe reports 142 file warnings across 221 source
files, including previously nonempty sections; the guard deliberately
refuses to replace those files while local-binding semantics remain unaudited.
Reproduce the cell-level JSON report with
`julia --project=converter converter/scripts/audit-cells.jl vendor/Rubi`.
See the [translation proposal](rubi-translation-proposal.md) for the pending
semantic and ordering decisions.

The read-only source-order audit
`python3 scripts/audit_rubi_order.py vendor/Rubi rules` compares exact source
file identities and reports unlisted files. On the pinned RUBI source, the
default configuration loads 198 files; 23 OSR files are outside that source
load list. The default manifest follows that file order, but array positions
and rule identifiers do not by themselves prove Mathematica's final runtime
priority. It contains 30 still-empty loaded files. The audit itself does not
reconstruct missing rules or modify the manifest.
The converter's manifest updater preserves this reviewed sequence and rejects
missing or duplicate entries; it does not infer new source ordering.

An opt-in **experimental** conversion preserves `Star` and validated `With`
syntax for isolated investigation; it is not a public rule export. At the
same source pin it converted 186 of 221 files, producing 6,951 candidate rules;
35 files still failed on unsupported scope or syntax. All 186 generated
candidate files passed JSON Schema and the revised semantic-closure validator;
24 contain `Star` and 104 contain `With`. For example, 1.1.2.1 produced 33
candidates retaining `Star`. These numbers include source files RUBI may not
load and do not establish mathematical correctness, execution equivalence,
or formal verification. Consumers must implement the extension contract
before any affected rules are published for execution.

The opt-in `converter/scripts/recover-empty.jl` creates a separate report and
candidate tree for currently loaded empty files, without writing to the
production corpus. At source revision `61e9c18`, it produces 822 candidate
rules in 23 files and reports seven files blocked. This does not reduce the 30
empty files in the production manifest; candidate syntax and schema validation
are not evidence of mathematical correctness or execution equivalence.
The read-only `audit-module.jl` command classifies the blocked files. On this
revision its parser finds 15 `Module` nodes, with 14 initialized and four
uninitialized local declarations. The parser now retains compound function
applications and postfix prime notation and parses all 21 code expressions
in the derivative file. Export remains blocked because neither construct has a
reviewed OSR mapping; parsing is not a semantic or proof check.
The trigonometric file uses the legacy line-based parser, whose source coverage
has not been established, so these counts are not an exhaustive corpus audit.
Nested body assignment counts can overlap and do not establish runtime behavior.

Section 1.4.1 needs particular care: its sum-by-term integration rule is
inside an `If[TrueQ[$LoadShowSteps], …]` source cell, with different branches
for step display. Treating the cell as one ordinary rule or ignoring its
condition would not preserve RUBI's loading behavior. That file remains
unsupported in the experimental full-file conversion.
At source revision `61e9c18`, `Rubi.m` defaults `$LoadShowSteps` to true
when ``Global`$LoadShowSteps`` has no value. The converter now has an isolated
branch selector that requires an explicit boolean, checks both branches are
single `Int` definitions, and rejects other conditions. It permits analysis
of either branch but does not publish either rule or assume the default.

## Converter numeric limitation

The converter now rejects integer AST values represented as Julia `BigInt`
instead of converting them to `Float64`. With the JSON3 pretty writer used by
the converter, `BigInt` values can be rounded during serialization. A failed
conversion reports a warning and does not write a partial rule file. Existing
converted files have not been exhaustively audited for historical rounding.

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
