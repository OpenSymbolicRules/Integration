# Rubi 4.17.3.0 reference edition

Start with [the release manifest](../editions/rubi-4.17.3.0/rules/meta.json) for new OSR integration work. Its 198 files follow the loader of Albert D. Rich's final version, published posthumously on 18 December 2023. Enable elementary rules, disable step display, and preserve both the file and array order. The manifest contains **7,249 converted source entries**. A host must implement the predicates, optional patterns, variable binding and operational heads it uses. In particular, preserve the distribution and evaluation semantics of Rubi's `Star` even though its arithmetic result is a product. Source order alone also cannot reproduce every Wolfram downvalue priority. [Upstream release and paclet](https://github.com/RuleBasedIntegration/Rubi/releases/tag/4.17.3.0)

| Input or output | Identity and interpretation |
|---|---|
| Released engine | Git tag `4.17.3.0`, commit `f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4`. Official paclet SHA-256 `7949302d5988865222516ed27e29128b0e82e65f266b1ef344bda9bd2e3a11c5`. |
| OSR conversion | [Coverage ledger](../editions/rubi-4.17.3.0/coverage.json) includes the source path, file digest, converted count and omitted blocks with reasons. Each entry is addressed by release-qualified file identity and source ordinal. Pin the Integration commit to identify both the converter and its output. |
| Known false rewrite | Read [release errata](../editions/rubi-4.17.3.0/errata.json) before enabling a rule. Section 4.5.2.1 cell 48 rewrites a cosecant integral using an incorrect cosine residual. Match file identity, local ID and payload digest and skip this entry. |
| OSR compatibility profile | The existing [7,209-entry manifest](../rules/meta.json) uses maintenance revision `61e9c18ea248061cd83c67882f7c91a73cef912d`. It has its own addresses and the same erratum at local ID 47. Existing v1 proof references use this lineage. |
| Tests | The 72,523 distributed examples in `tests/` have separate provenance. The paclet does not package this corpus. OSR pins [MathematicaSyntaxTestSuite](https://github.com/RuleBasedIntegration/MathematicaSyntaxTestSuite/tree/32b79cedb8a5a80e82e6db9f67e9cdf88cf11217). The upstream [website TestFiles](https://github.com/RuleBasedIntegration/RuleBasedIntegration.github.io/tree/847499d12b0b5e66b6a50838eeea3e0f231aa69e/TestFiles) is another edition. Their expected steps and reference expressions can differ. |

At the OSR compatibility snapshot `8c22e67`, regenerating the independent fixture suite with the checked-in converter produces 72,478 entries. Five distributed files differ. In particular, consumer campaigns should pin the JSON snapshot and the source edition before comparing step counts. [Converter drift run](https://github.com/OpenSymbolicRules/Integration/actions/runs/45549029660)

The loader, package metadata, utility file and all 198 loaded rule files agree byte for byte between the release Git tree and the paclet. The maintenance revision also declares 4.17.3.0. Eight subsequent commits changed upstream, including definite-integral checks and limit directions. A version string cannot distinguish the two. Do not add the two profile counts or transfer a proof by matching a bare ID. [Upstream revision comparison](https://github.com/RuleBasedIntegration/Rubi/compare/f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4...61e9c18ea248061cd83c67882f7c91a73cef912d)

The converter records 145 omitted source blocks. Of these, 108 use unsupported local scope or assignment and 21 use compound application heads. Some omitted blocks define helpers. Sections 4.1.8 and 9.1 have no converted entries. Coverage counts describe transcription. Rule applicability, mathematical validity and compiled Lean evidence must be evaluated independently. The release archive carries the [upstream MIT notice](../editions/rubi-4.17.3.0/LICENSE). See also [the source-profile and verification notes](source-edition.md).

## Reproduce the released edition

Use the repository's converter environment. The output directory must be new. The producer reads Git objects directly and works with any Rubi checkout containing the pinned commit. Pass the optional downloaded paclet to verify the archive digest and all 201 source blobs.

```sh
git submodule update --init vendor/Rubi
julia --project=converter -e 'using Pkg; Pkg.instantiate()'
python3 scripts/rubi_release.py vendor/Rubi /tmp/osr-rubi-release --paclet /path/to/Rubi-4.17.3.0.paclet
python3 scripts/check_expanded_profile.py /tmp/osr-rubi-release/rules editions/rubi-4.17.3.0/rules
cmp /tmp/osr-rubi-release/coverage.json editions/rubi-4.17.3.0/coverage.json
cmp /tmp/osr-rubi-release/errata.json editions/rubi-4.17.3.0/errata.json
cmp /tmp/osr-rubi-release/LICENSE editions/rubi-4.17.3.0/LICENSE
```

See [post-release CAS rules and regression cases](post-rubi.md) for additions with independent provenance.
