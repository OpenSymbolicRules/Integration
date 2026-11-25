# Reproducing Rubi integration fixtures

The OSR converter serializes **72,584 recognized tuples across 215 JSON files** from MathematicaSyntaxTestSuite commit `32b79cedb8a5a80e82e6db9f67e9cdf88cf11217`. This pin identifies the test sources independently of the Rubi engine version. Pin the Integration commit as well to identify the converter and JSON. Run the following commands from the repository root with a fresh output directory. [Upstream test suite](https://github.com/RuleBasedIntegration/MathematicaSyntaxTestSuite/tree/32b79cedb8a5a80e82e6db9f67e9cdf88cf11217)

```sh
git submodule update --init vendor/MathematicaSyntaxTestSuite
julia --project=converter -e 'using Pkg; Pkg.instantiate()'
julia --project=converter converter/scripts/convert.jl --tests /tmp/osr-fixture-check
diff --brief --recursive tests /tmp/osr-fixture-check
```

## Changed cases and identifiers

Integration commit `00784d9` distributed 72,523 cases. Its converter reproduced 72,478. All previously published path and case ID pairs are retained. The following corrections explain the difference. [Prior snapshot](https://github.com/OpenSymbolicRules/Integration/tree/00784d9a30a06ae6ce57c75b264f5d9bdfe5d6e0/tests)

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

The batch writer stages the files before publication. A warning on a recognized tuple stops the batch and identifies its file and case ID. CI compares the complete regenerated directory, including missing or additional files. The count measures tuples recognized by the existing source parser. Alternative primitives beyond the fourth tuple field and conditional step-count selection retain the existing conversion policy.
