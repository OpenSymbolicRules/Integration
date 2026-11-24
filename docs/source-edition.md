# Recovering the default RUBI integration profile

Load the 198 files listed in `rules/meta.json`, in order, and read each
`rules` array in order. This loads **7,208** v0.1 entries. The other 23
files contribute 850 entries outside the default load sequence. The 7,208
loaded entries contain 7,130 distinct JSON triples of pattern, ordered
constraints and result, using the same comparison as the duplicate checker.
This comparison recognizes exact duplicates and leaves mathematical
equivalence open. File identity
and local rule ID address a rule. Array position determines its priority.
New IDs can therefore appear between smaller ones.

The converter reads Git blobs at RUBI 4.17.3.0 revision
`61e9c18ea248061cd83c67882f7c91a73cef912d`. Elementary rules are enabled.
Of the 7,290 converted source definitions, 21 select the branch for disabled
step display. A further 147 blocks are recorded with their source and reason
for omission. They include local assignments, derivative applications and
source syntax outside the supported parser. Counting both branches of a
source conditional separately gives a different quantity. Source order also
does not model all Wolfram Language evaluation and downvalue precedence.

At Integration commit `85db3b3` the default profile had 5,504 entries.
The merge locates a unique ordered sequence matching the complete pattern,
constraints and result of every previous rule in a section. It retains those
entries including their IDs and provenance, then inserts intervening source
rules in source order. Each inserted rule gets an unused local ID and a
source locator. A locator's number is the notebook cell ordinal or, for the
legacy line format, the source line number. It can differ from the OSR ID.
This restored 1,704 entries across 111 sections. Three sections retain their
previous contents because their complete sequences did not match
(1.2.1.1, 1.2.2.3 and 4.1.7). Sections 4.1.8 and 9.1 still have zero
converted rules.

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

With the submodules initialized, generate a fresh conversion and reproduce
the shipped profile using the following commands. Use two new directories
and a checkout containing the baseline commit.

```sh
julia --project=converter converter/scripts/source-edition.jl vendor/Rubi /tmp/rubi-source
python3 scripts/merge_source_edition.py /tmp/rubi-source/rules /tmp/rubi-expanded
python3 scripts/check_expanded_profile.py /tmp/rubi-expanded rules
```

The first directory contains a separate v0.1 manifest with 7,290 entries,
source-based IDs and a coverage file with SHA-256 digests and omitted source
blocks for every file. Its count overlaps the default profile. The second
directory contains the default manifest and its loaded files, preserving
the compatibility baseline. The repository additionally retains the
historical unloaded files.
