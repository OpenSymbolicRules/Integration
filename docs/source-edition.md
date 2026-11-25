# Recovering the default RUBI integration profile

For Albert D. Rich’s final release, use the [4.17.3.0 reference edition](rubi-release.md). The following inventory describes the later maintenance checkout used by existing consumers.

Load the 198 files listed in `rules/meta.json`, in order, and read each
`rules` array in order. This loads **7,418** v0.1 entries. The other 23
files contribute 850 entries outside the default load sequence. The 7,418
loaded entries contain 7,335 distinct JSON triples of pattern, ordered
constraints and result, using the same comparison as the duplicate checker.
This comparison recognizes exact duplicates and leaves mathematical
equivalence open. File identity
and local rule ID address a rule. Array position determines its priority.
New IDs can therefore appear between smaller ones.

The converter reads Git blobs at RUBI 4.17.3.0 revision
`61e9c18ea248061cd83c67882f7c91a73cef912d`. Elementary rules are enabled.
Of the 7,418 converted source definitions, 22 select the branch for disabled
step display. A further 19 blocks are recorded with their source and reason
for omission. The file and array order reproduces source placement.
Wolfram Language evaluation and downvalue precedence also affect dispatch.

At Integration commit `85db3b3` the default profile had 5,504 entries.
The merge locates a unique ordered sequence matching the complete pattern,
constraints and result of every previous rule in a section. It retains stable IDs and inserts intervening source rules in source order. Each inserted rule gets an unused local ID and a
source locator. A locator's number is the notebook cell ordinal or, for the
legacy line format, the source line number. It can differ from the OSR ID.
This restored 1,704 entries across 111 sections. All 198 loaded sections now reconcile in source order. Relative to commit
`3d6b6b2`, the profile gained 209 entries across 35 sections. The 19 entries
in 1.2.1.1 include the general quadratic substitutions at local IDs 18 and 19
(upstream lines 21 and 22). Local ID 13 now carries the complete source bound
`3 <= Denominator[p] <= 4` from line 19. The previous conversion lost the
upper endpoint. Sections 1.2.2.3 and 4.1.7 now contain 100 and 73 entries.
Section 4.1.8 supplies eight entries. The eight converted rules in the loaded
9.1 derivative file carry the same real-theorem references as the release.
The two editions use identical upstream bytes for that file.

The edition converter preserves initialized and uninitialized locals in
`Module`, including locals used by nested iterators and guards. Allocate
fresh symbols for each invocation. Keep local guards inside their binder.
The three-argument predicate `LessEqual[3,d,4]` tests both endpoints. A host
that implements only binary comparisons must handle the full chain or
decline that rule. Sequential `Module` statements assign declared locals in order. In
section 9.3, `Not[FalseQ[r=Divides[...]]]` both binds the returned value
and tests it before the result uses it. Preserve short-circuit evaluation.
`UnsameQ` in the normalizer guard compares expression structure. Section
8.6 dynamically binds `$UseGamma` during recursive integration.
Counting both step-display branches yields 7,453 upstream `Int`
definitions. With step display disabled, 22 alternative branches drop out.
The other 13 definitions have full source transcriptions outside the load order. Each is in section 9.1. The ledger also retains
five helper definitions and one initialization. See the [release coverage](rubi-release.md) and
[unresolved exponential helpers in the maintenance tree](../upstream-bugs.md).

A consumer needs the semantics of every operation and predicate in a rule.
For example, the recovered sums rule uses `SumQ[u]` and calls RUBI's
`IntSum[u,x]`. The upstream helper extracts constant terms and applies
`IntTerm` to the remainder. The manifest declares RUBI's binary `Star`
extension. A host must preserve its distribution and evaluation behavior
and decline those rules when that capability is unavailable. `With`
requires simultaneous lexical binding. Names in the existing `openmath:osr#`
convention require a host implementation. These conversion counts include
entries whose execution and mathematical correctness have yet to be checked.
The v1 report records independent, domain-specific proof results.

The wrapped definitions reported by John Verzani now have the following
stable local IDs. The three columns refer to the pinned RUBI loader with
step display disabled. Each source definition contributes one loaded entry.

| Section | RUBI source ordinals | Distributed OSR IDs in matching order |
|---|---|---|
| 1.4.1 | 9 | 71 |
| 3.5 | 46 | 44 |
| 4.1.0.1 | 4 | 25 |
| 4.7.5 | 24, 25, 50, 51, 61, 74 | 33, 34, 57, 58, 65, 72 |
| 5.3.7 | 30, 31 | 74, 75 |
| 7.3.7 | 28, 29 | 69, 70 |
| 9.3 | 38, 39, 52, 53, 54, 56, 57, 58, 67 | 34, 35, 48, 49, 50, 52, 53, 54, 62 |

Commit `f44efda` already includes 21 of the 22. The remaining
tangent half-angle substitution (4.7.5 #72) computes a trial integral
with dynamically scoped step settings in `Block`, tests `CalculusFreeQ[w,x]`
inside `With`, and evaluates an assignment to a fresh `Module` local before
returning the substitution. Consumers must decline this rule if they cannot
implement these operations. The manifest records the required built-ins.
The compatibility merge uses Integration snapshot `75c07bb` to preserve
published IDs while inserting in source order. In section 9.1 source cells
9 and 12 receive local IDs 7 and 8, before local IDs 4–6 in the array. See also the separate
[cosecant erratum](../upstream-bugs.md) and its
[machine-readable exclusion](rubi-errata.json).

With the submodules initialized, generate a fresh conversion and reproduce
the shipped profile using the following commands. Use two new directories
and a checkout containing the baseline commit.

```sh
julia --project=converter converter/scripts/source-edition.jl vendor/Rubi /tmp/rubi-source
python3 scripts/merge_source_edition.py /tmp/rubi-source/rules /tmp/rubi-expanded
python3 scripts/check_show_steps.py vendor/Rubi /tmp/rubi-source rules
python3 scripts/check_expanded_profile.py /tmp/rubi-expanded rules
```

The first directory contains a separate v0.1 manifest with 7,418 entries,
source-based IDs and a coverage file with SHA-256 digests and omitted source
blocks for every file. Its count overlaps the default profile. The second
directory contains the default manifest and its loaded files, preserving
the compatibility baseline. The repository additionally retains the
historical unloaded files.
