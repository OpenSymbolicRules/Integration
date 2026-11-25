# Reproducing Rubi integration fixtures

The OSR converter serializes **72,254 active tuples across 215 JSON files** from MathematicaSyntaxTestSuite commit `32b79cedb8a5a80e82e6db9f67e9cdf88cf11217`. This pin identifies the test sources independently of the Rubi engine version. Pin the Integration commit as well to identify the converter and JSON. Run the following commands from the repository root with a fresh output directory. [Upstream test suite](https://github.com/RuleBasedIntegration/MathematicaSyntaxTestSuite/tree/32b79cedb8a5a80e82e6db9f67e9cdf88cf11217)

```sh
git submodule update --init vendor/MathematicaSyntaxTestSuite
julia --project=converter -e 'using Pkg; Pkg.instantiate()'
julia --project=converter converter/scripts/convert.jl --tests /tmp/osr-fixture-check
diff --brief --recursive tests /tmp/osr-fixture-check
just fixture-index /tmp/osr-fixture-sources.json
cmp docs/fixture-sources.json /tmp/osr-fixture-sources.json
```

## Locating a case and selecting reference data

Use the [machine-readable source index](fixture-sources.json) to join a fixture to its original Wolfram source. Find the file record by `json_file`, locate the case ID in the fixture's `tests` array and use that array position in `source_lines`. A number denotes a single one-based source line. A pair denotes an inclusive multiline span. The index records SHA-256 digests of the source file, distributed JSON, converter inputs and environment lock. The toolkit version comes from the Julia project. The upstream repository contains an MIT notice. Some independent collections name additional authors or publications in their file headers. Per-collection redistribution rights need separate review. To reproduce a campaign, pin the Integration commit for the JSON, index and converter, along with the upstream commit identified in the index.

In 872 active cases the source supplies fields after the primary reference primitive. The index retains them in order as OSR expressions in `details[].extra_fields`. Their mathematical equivalence and branch conditions require separate review. For 49 cases `details[].source_steps` retains the complete conditional expression. The v0.1 integer `num_steps` uses Wolfram Language version 11 for this edition. All thresholds at this source pin are 8, 9 or 11, so the same values apply for later Wolfram Language versions. For example, Timofeev case 416 selects −28 below version 11 and −27 otherwise. Negative step counts retain their upstream meaning. A new form of step expression requires an explicit conversion decision.

## From the line-based snapshot to active cases

Commit `938a888` reproduced 72,584 cases. Its line-based reader recognized 331 tuples inside multiline comments across 26 source files. Their former IDs are reserved. The [withdrawn case table](../converter/data/retired-fixture-ids.json) maps each source path to pairs of historical case ID and one-based source line. The [previous JSON snapshot](https://github.com/OpenSymbolicRules/Integration/tree/938a888c404dd9d76de517404d26afc33fec9a47/tests) preserves the original payloads for frozen selections.

Reading the complete files also recovers Gamma case 233 at source line 417. Its integrand contains the postfix factorial of a+b·x. Of the 72,253 retained cases, 17 have corrected step counts from the second branch of a version condition. Every retained case keeps its ID, integrand, variable and primary reference. The input and output hashes establish which dataset an adapter consumed. Reproduction alone establishes no primitive's mathematical validity.

## Earlier conversion corrections

Integration commit `00784d9` distributed 72,523 cases. Its converter reproduced 72,478. Commit `938a888` retained the previously distributed case IDs and made the following corrections. [Prior snapshot](https://github.com/OpenSymbolicRules/Integration/tree/00784d9a30a06ae6ce57c75b264f5d9bdfe5d6e0/tests)

| Family | Correction |
|---|---|
| 8.10 Formal derivatives | Recover the 61 cases formerly skipped when parsing postfix primes. Preserve IDs 1–36 for the previously distributed cases and assign IDs 37–97 to the recovered cases, in source order within each group. The JSON array follows the original tuple order. For example, source tuple 1 is case 37 and source tuple 4 is case 1. |
| 3.2.2 Logarithms | Restore the four held substitution heads in reference expressions at IDs 253, 254, 262 and 263. |
| Welz problems, 1.3.2 Algebraic functions and 8.6 Gamma functions | Preserve large integer literals in five cases. All 127 occurrences outside the signed 64-bit range in these corrections are emitted as exact decimal JSON integers. Consumers need a lossless number reader before passing them to a CAS. |
| 2.3 Exponential functions | Preserve the real literals `-100.` and `10.` as `-100.0` and `10.0` in the reference primitive for the source integral of x/exp(0.1x). |

## Reading formal results

For the test expression `f''[g[x]]`, the JSON encodes `Derivative[2]` applied first to f, then to g(x). The core OSR v0.1 operator `Apply` takes a head and a list of arguments. Keeping the evaluation point separate from the derivative variable avoids differentiating the composition by mistake.

```json
["Apply", ["Apply", ["Derivative", 2], ["List", "f"]], ["List", ["g", "x"]]]
```

`Defer[Subst][r,u,v]` uses `["Apply", ["Defer", "Subst"], ["List", r, u, v]]`, where r, u and v denote the three encoded source expressions. Keep the held head when comparing reference results. The manifest declares both fixture operators. Preserve symbolic and negative derivative orders literally. A consumer that lacks the corresponding interpretation should report that case as unsupported. These forms describe the expected results supplied by Rubi. A mathematical proof or a claim that a CAS can evaluate them requires separate evidence. [Derivative](https://reference.wolfram.com/language/ref/Derivative.html) · [Defer](https://reference.wolfram.com/language/ref/Defer.html)

The batch writer stages the files before publication. A warning on a recognized tuple stops the batch and identifies its file and case ID. CI compares the complete regenerated directory, including missing or additional files. The fixture reader tokenizes entire files, skips nested Wolfram comments and requires complete outer tuples. Unconsumed input or an unsupported step count fails the batch. CI also regenerates the source index from the pinned Git blobs.
