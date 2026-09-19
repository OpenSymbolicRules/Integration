# Known Issues in the Converted RUBI Corpus

Defects of the conversion itself, as opposed to the RUBI source. Each entry
states how it was measured so that it can be re-measured after a fix.

Measured against: this repository at 6,257 rules in 188 rule files, converted
from Rubi 4.16.1; `OpenSymbolicRules.jl` 0.1.0; Julia 1.13.0.

## 1. The integration variable is lost

**What happens.** RUBI writes an integration rule as
`Int[integrand, x_Symbol] := antiderivative /; conditions`. The converter keeps
the integrand as the rule's `pattern` and drops the `Int[..., x_Symbol]`
wrapper. Two things go with it:

* the binding of `x`. 254 rules name `x` in a `result` or a `constraint`
  although their `pattern` never bound it, so a host must supply a global symbol
  literally named `x` for the rule to apply at all. Another 103 rules name some
  other unbound symbol, most of them inert trigonometric heads such as `sin`;
  those are legitimate free values, `x` is not.
* the `x_Symbol` restriction, which required the integration variable to be a
  symbol. Without it a rule matches integrands it was never meant to. Rule
  `1.1.1.1:2`, `x_^m_. => x^(m+1)/(m+1)`, matches the constant integrand `-2`
  and returns `(-2)^2/2`; the antiderivative is `-2 x`.

**Effect, measured.** Running `just conformance 1.1.1` in the
`OpenSymbolicRules.jl` checkout over section 1.1.1 — 906 test problems against
186 rules — gives 903 closed forms, 1 unchanged, 2 errors, and **0** results
matching the recorded antiderivative. The rule set answers almost every problem
and answers none of them correctly.

**How to reproduce.**

```
cd ../OpenSymbolicRules.jl && just conformance 1.1.1
```

**What a fix has to preserve.** A rule needs to carry its integration variable
as a binding and to record that the binding ranges over symbols. Whether that is
an explicit `Int` head in the pattern, a `variable` field on the rule, or a
`Symbol`-typed wildcard is a specification question; dropping it is not an
option, because the current corpus is unsound rather than merely incomplete.

## 2. Empty rule files

33 of the 222 rule files carry `"rules": []`. They correspond to RUBI sections
the converter produced no rules for. The section is declared in `meta.json` and
in the file, so a loader sees a section that contributes nothing.
