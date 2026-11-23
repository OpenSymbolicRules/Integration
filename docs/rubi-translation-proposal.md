# RUBI multiline conversion: semantic decisions for review

This proposal does not change the OSR specification or publish candidate
rules. Evidence is the pinned RUBI commit
`61e9c18ea248061cd83c67882f7c91a73cef912d`, whose `Rubi/PacletInfo.m`
declares `4.17.3.0`. The historical Integration metadata labels the corpus
`4.16.1`; the discrepancy requires an audit rather than a silent relabelling.

## `Star` is not an ordinary formatting marker

RUBI's `IntegrationUtilityFunctions.m`, section `Star[u,v]`, describes a
product with distribution. Its implementation also depends on `$ShowSteps`,
whether the second operand contains integrals, zero factors, and nested
`Star` expressions. A CAS using ordinary multiplication may produce a different
intermediate expression or evaluation trace, even where the intended
mathematical value is a product. This matters when later rewrite order is
significant.

Candidate approaches, neither implemented as a rule export here:

1. **Preserve the operation.** Agree on a versioned, reviewed vocabulary and
   an operational contract for `Star`; consumers that cannot execute it must
   explicitly decline it. This best preserves the source expression but needs
   a vocabulary decision outside the current Integration converter.
2. **Offer a restricted value-level profile.** Translate to mathematical
   multiplication only when an explicit contract establishes the intended
   evaluation regime and acceptable loss of operational behavior. This needs
   a proof or review of definedness, distribution and affected downstream
   rewrites. It must not be labelled execution-equivalent to RUBI by default.

Until one path is reviewed, the converter keeps `Star` in its internal syntax
and rejects affected files instead of inventing an OpenMath symbol or
publishing a silent replacement.

## Local bindings

OSR v0.1's structural catalogue mentions `With`, `Module` and `Set`, but a
converter and consumer still need a shared account of lexical binding,
evaluation order and variable capture. For example, a local `k` in
`With[{k=Denominator[m]}, body]` must not capture a free `k` in a substituted
expression. The parser recognizes these constructs, but export currently
rejects them. A future implementation should test nested scopes, shadowing,
simultaneous definitions, free variables and unsupported constructs, and
document which consumers can execute the resulting form. A capture-avoiding
elaboration is an alternative only when its equivalence is established.

## Source order and identifiers

RUBI's `Rubi.m` orders loaded files. The converter's current `meta.json`
generator sorts file paths; do not conflate those sequences. A future source
order manifest should record the exact upstream revision, active load calls,
configuration and the source file path for each entry. A legacy local rule ID
is a locator, not itself a proved global execution rank. Rules from files not
loaded by that RUBI configuration, unavailable rules, and OSR-only variants
must not receive invented upstream ranks. Tests must cover commented calls,
conditional loads, duplicate paths and unmatched entries before use by a CAS.

## Remaining syntax

The cell audit reports four candidate cells with derivative notation or the
`=!=` operator that still do not parse. Their Wolfram semantics and the
available OSR representations require separate tests. Cell parse counts are
not a substitute for schema validation, numerical checks or formal proof.
