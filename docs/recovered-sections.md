# Recovered RUBI integration rules

The [archive](../converter/recovery/files.json) lists the 30 sections that were
empty in the default manifest at Integration commit `a0932a7`. Each path names
a JSON document under `converter/recovery/` and the corresponding rule file
under `rules/`. The archive retains the complete upstream source text of all
30 files at RUBI 4.17.3.0, commit `61e9c18ea248061cd83c67882f7c91a73cef912d`.
It includes the upstream MIT license. Concatenating the UTF-8 strings in
`blocks[].source` reproduces the upstream Git blob, including comments and
line endings. Each archive records its SHA-256.

| Recovered block | Count | Available representation |
| --- | ---: | --- |
| Converted | 68 | Source and OSR v0.1 rule, also present in the default profile |
| Candidate | 1,007 | Source and converted pattern, constraints and result under `rule`, with extra operator heads under `required_heads` |
| Conditional | 1 | Source and both OSR translations keyed by the value of RUBI's load flag |
| Source syntax tree | 36 | Parsed RUBI definition, exact source and conversion error (compound application or local assignment) |

These counts omit headers and comment-only or blank blocks. The default loader
now reads 5,504 entries. Eleven sections gained rules and nineteen still
require operations outside the converter's default selection. Rule IDs in
these newly populated sections use the one-based notebook code-cell ordinal,
including skipped cells. The legacy line-format archive uses line numbers.
The array preserves relative source order. Missing earlier rules can change
which rule a consumer selects. New entries carry conversion provenance and
require their guards to hold. Recovery adds no Lean certificates.

For example, 1.1.2.1 cell 2 gives the primitive
`x/(a*Sqrt[a+b*x^2])` for `1/(a+b*x^2)^(3/2)` with RUBI's original
`FreeQ[{a,b},x]` guard. A real CAS also needs to establish the domain of
that expression, including a nonzero denominator.
In 1.4.1 cell 9, the branch for disabled step display retains
`IntSum[u,x]` and the `SumQ[u]` guard. The other branch retains
`ShowStep` and `SimplifyFlag`. A consumer applying this cell needs RUBI's
helper and flag behavior.

To regenerate both trees in a fresh directory, run
`julia --project=converter converter/scripts/recover-profile.jl vendor/Rubi /tmp/rubi-recovered`.
The converter reads the pinned Git blobs. Run
`python3 scripts/test_recovered_profile.py` with the RUBI submodule initialized
to compare the packaged sources byte for byte and verify default profile membership.
