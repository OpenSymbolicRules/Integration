# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Report `5ea2f5e8…`: the nine rules migrated in `37faa87a…` declared
  exponent metavariables independent of x without an `independence:`
  finding, so `scripts/check-v1.sh` failed on the v1 files distributed with
  that report; the findings are added and the check passes.

### Added
- Report `41cc6232…`: six more RUBI rules are migrated, five proved by parts
  (6.1.12 #27, #28, 4.1.12 #41, #42, 3.3 #9) and one refuted (5.3.5 #7); 1007
  rules.
- Report `eea66e08…`: four more RUBI rules are migrated, three refuted (5.3.4
  #144, 6.3.12 #3, #4) and one proved (1.2.2.3 #25); 1001 rules.
- Report `0caffa06…`: eight more RUBI rules are migrated, five proved (7.3.1
  #1, 7.3.4 #41, 7.3.7 #41, 6.7.9 #73, #75) and three refuted over ℝ and ℂ
  (4.7.6 #4, #5, 6.7.6 #4); 997 rules.
- Report `e79b3e32…`: 21 more RUBI rules are migrated, 19 proved and two
  refuted over ℝ (6.7.9 #86 to #89, 4.7.9 #94 to #97, 6.7.7, 4.7.7 and 6.7.8);
  989 rules.
- Report `0c1101a8…`: 48 more RUBI rules are migrated and proved over ℝ, eight
  of them over ℂ too (7.2.3, 7.2.4, 6.7.9, 6.1.11, 7.3.4, 7.3.1, 4.7.9, 4.7.6,
  6.7.6, 7.3.7, 5.3.7, 6.7.7, 5.1.1, 5.1.2, 7.1.1, 7.1.2, 7.2.1 and 7.2.2); 968
  rules.
- Report `d285fa25…`: six RUBI splits with a shifted exponent (7.3.4 #5,
  #95, 7.3.1 #25, #115, 5.3.4 #5, #95) are migrated and proved over ℝ; 920
  rules.
- Report `7f700cf4…`: eight more RUBI linear splits (7.3.x and 6.1.12) are
  migrated and proved over ℝ; 914 rules.
- Report `bba020e2…`: 7.3.4 #39 and 7.3.1 #59 are migrated and proved over
  ℝ; 906 rules.
- Report `cf523cae…`: six more RUBI rules (7.3.4 #89, #91, 7.3.1 #109,
  #111, 5.3.4 #89, #91) are migrated and proved over ℝ; 904 rules.
- Report `d9ebd02b…`: five more RUBI rules (5.3.7 #13, #43, #45, 7.3.4 #13,
  7.3.7 #13) are migrated and proved over ℝ; 898 rules.
- Report `ff17058b…`: ten more RUBI rules (arctanh and arctan families) are
  migrated and proved over ℝ by integration by parts; 893 rules.
- Report `b4b80ded…`: 19 more RUBI rules not considered before are migrated
  and refuted over ℝ; 883 rules.
- Report `8dc11a68…`: 14 more RUBI rules not considered before (5.3.4,
  7.3.1, 7.3.4 and 6.7.7) are migrated and proved, 4 of them also over ℂ;
  864 rules.
- Report `574f2788…`: 247 RUBI rules not considered before, including
  reciprocal, hyperbolic, inverse and square-root rules, are migrated and
  refuted (all over ℝ, 53 over ℂ); 850 rules.
- Report `37faa87a…`: nine RUBI rules not considered before (1.2.1.2 #93–95,
  1.2.3.3 #41, #42, #47 and 1.2.3.4 #92, #93, #100) are migrated and proved
  over ℝ and ℂ as RUBI states them; 603 rules.
- Report `be992810…`: seven more strengthened variants (1.3.1 #4, 1.3.2 #1
  and 2.3 #11, #23, #24, #26 and #35, the latter with `F > 0`) are proved over
  ℝ and ℂ; 594 rules.
- Report `59e5b849…`: six strengthened variants with a tighter exponent bound
  or more nonzero conditions (1.2.2.4 #59–62, 1.1.1.3 #53 and 3.4 #7) are
  proved, five over ℝ and ℂ and one over ℝ only; 587 rules.
- Report `3bcfa359…`: eight strengthened variants whose candidates had
  failed the numerical truth check at a single zero are proved with that zero
  excluded, one over ℝ and ℂ and seven over ℝ only; 581 rules.
- Reports `83ab90fe…` and `be9100af…`: 23 strengthened variants whose
  candidates had been sampled too rarely (an `EqQ` condition) are sampled
  again with the equalities solved and proved, 19 over ℝ and ℂ and four over
  ℝ only; 573 rules.
- Report `2f2be88e…`: eight strengthened variants refuted by the pole probe
  are corrected with one more nonzero exponent and proved (1.1.3.3 #18 over ℝ
  and ℂ; 3.2.1 #2 and #13, 3.2.3 #2, #4 and #7, 3.3 #7 and 3.5 #23 over ℝ
  only); 550 rules.
- Report `76ee6db2…`: strengthened variants of nineteen refuted named rules
  (1.1.1.3 #8, 4.1.13 #3, …) are added, proved over ℝ and ℂ (thirteen) or over
  ℝ only (six); 542 rules.
- Reports `63a96db2…` to `f4757237…`: the last 19 strengthened variants
  distributed unproved are proved (118 over ℝ and ℂ, 24 over ℝ only); the
  variant of 3.3 #22 now also appends `n ≠ 0`, as it was false at `n = 0`.
- Reports `00a94414…` to `82672d5c…`: six more strengthened variants are
  proved over ℝ only (15 in all); 19 remain distributed unproved with a
  numerical check.
- Reports `7ef66d2f…` to `aa90538a…`: six more logarithmic strengthened
  variants are proved over ℝ only (nine in all); 25 remain distributed
  unproved with a numerical check.
- Reports `2b296f3e…` to `ca7e9f18…`: five more strengthened variants are
  proved (108 in all) and three logarithmic ones over ℝ only; 31 remain
  distributed unproved with a numerical check.
- Reports `6430a1e2…` to `43563e7c…`: 28 more strengthened variants are
  proved (103 in all), among them the first trigonometric and logarithmic
  ones; 39 remain distributed unproved with a numerical check.
- Reports `90265091…` to `65fee808…`: eleven more strengthened variants are
  proved (75 in all); 67 remain distributed unproved with a numerical check.
- Reports `dbf6b787…` to `5af3c5a6…`: nine more strengthened variants are
  proved (64 in all); 78 remain distributed unproved with a numerical check.
- Reports `0f686088…` to `a818d70c…`: the v1 set has 523 rules; 142 are
  strengthened variants of refuted rules, 55 of them proved and 87 distributed
  unproved with a numerical check (`numerical:` findings). 381 transcriptions
  are faithful to v0.1.
- Reports `75895afd…` to `37b59f6e…`: the v1 set has 408 rules; strengthened
  variants of 1.2.3.5 #2, 1.2.1.3 #13, #14, #24 and #25, 1.1.1.7 #6 and 1.1.1.3
  #9 are proved and certified over ℝ and ℂ. 381 transcriptions are faithful to
  v0.1 and 27 strengthened.
- Reports `5b1bc665…` and `86e9259d…`: the v1 set has 401 rules; strengthened
  variants of 1.1.1.3 #2, 1.2.1.1 #3, 1.2.1.2 #55, 4.1.12 #81 and #82, 1.2.1.4
  #65 and #66 are proved and certified over ℝ and ℂ. 381 transcriptions are
  faithful to v0.1 and 20 strengthened.
- Report `4a53a417…`: the v1 set has 394 rules; strengthened variants of
  1.2.1.2 #4, 1.2.1.3 #1 and 1.2.1.4 #1 are proved and certified over ℝ and ℂ.
  381 transcriptions are faithful to v0.1 and 13 strengthened.
- Report `5eeda009…`: the v1 set has 391 rules; strengthened variants of
  1.1.3.3 #10 and 1.1.3.4 #14 are proved and certified over ℝ and ℂ. 381
  transcriptions are faithful to v0.1 and 10 strengthened.
- Report `5df371f5…`: the v1 set has 389 rules; four more strengthened
  variants (1.1.1.2 #1, 1.1.3.2 #3, 1.1.3.1 #3 and 1.1.3.2 #6) are proved and
  certified over ℝ and ℂ. 381 transcriptions are faithful to v0.1 and 8
  strengthened.
- Report `13c7663e…`: the v1 set has 385 rules; four strengthened variants
  (1.1.1.1 #4, 9.1 #9, 4.1.13 #11 and #12 with a non-degeneracy condition) are
  proved and certified over ℝ and ℂ. 381 transcriptions are faithful to v0.1
  and 4 strengthened.
- `scripts/v1_faithfulness.py` accepts strengthened rules (Specification
  V1-R-005e): conditions appended after the converted v0.1 conditions, declared
  by a `strengthened:` finding, are counted separately.
- Reports `cbcbcb7e…` and `c508b1ac…`: the v1 set has 381 rules; 1.1.3.5 #42,
  1.1.3.6 #30 and 1.2.3.3 #56, #57 are proved and certified over ℝ and ℂ. All
  381 transcriptions are faithful to v0.1.
- Reports `fdee9c1b…` and `93cdf533…`: the v1 set has 377 rules; 1.1.3.5 #41 and
  1.1.3.6 #29 are proved and certified over ℝ and ℂ. All 377 transcriptions
  are faithful to v0.1.
- Reports `b2ee9abf…` and `99ef8103…`: the v1 set has 375 rules; 1.2.3.1 #1 and
  1.1.3.4 #45 are proved over ℝ and ℂ. All 375 transcriptions are faithful to
  v0.1.
- Reports `f8703dd9…`, `6f5b2f4d…` and `e85967a3…`: the v1 set has 373 rules; 12
  more refuted from random sampling, 1.2.4.1 #1 and 1.2.4.2 #1 proved, and 27
  half-integer rules reported as not migrated. All 373 transcriptions are
  faithful to v0.1.
- Report `aba1d4f5…`: the v1 set has 359 rules; 39 more RUBI rules from a wider
  inventory pass are refuted (38 in both domains). All 359 transcriptions are
  faithful to v0.1.
- Reports `4e719fca…`, `e0a3499e…` and `9caf6485…`: thirteen rules with `log`
  refuted over ℂ at the branch cut of the principal logarithm; no statement
  is left unproved in either domain (53 proved and 267 refuted over ℂ).
- Report `f3212525…`: eight one-domain refutations carried to the other
  domain (3.1.5 #33 over ℝ; 3.4 #9, 4.7.6 #2, 1.2.2.2 #19, 3.5 #14, #17,
  #22, #23 over ℂ); 61 proved and 259 refuted over ℝ, none unproved.
- Report `1255db02…`: the v1 set has 320 rules; 1.1.3.2 #69 (by parts) is
  proved over ℝ and ℂ (61 proved, 258 refuted and one unproved over ℝ). All
  320 transcriptions are faithful to v0.1.
- Report `65b5cda4…`: the v1 set has 319 rules; 3.3 #15 and 1.2.1.2 #101
  are proved over ℝ and ℂ, 1.2.1.2 #103 is refuted at `m = p = -1` (60
  proved, 258 refuted and one unproved over ℝ). All 319 transcriptions are
  faithful to v0.1.
- Report `fbfcffe6…`: the v1 set has 316 rules; 3.1.2 #8 and 4.7.9 #80 are
  proved over ℝ and ℂ (58 proved, 257 refuted and one unproved over ℝ). All
  316 transcriptions are faithful to v0.1.
- Report `322b4cca…`: the v1 set has 314 rules; 4.7.7 #34 and #35 are
  proved over ℝ and ℂ, 1.2.1.2 #54 and #59 refuted at `d = b = 0` (56
  proved, 257 refuted and one unproved over ℝ). All 314 transcriptions are
  faithful to v0.1.
- Report `d5681743…`: the v1 set has 310 rules; 4.7.9 #9, #10 and 4.7.7
  #26, #27 are proved over ℝ and ℂ, and 4.7.7 #32 is refuted at `x = π`
  (54 proved, 255 refuted and one unproved over ℝ). All 310 transcriptions
  are faithful to v0.1.
- Report `621dc8cf…`: the v1 set has 305 rules; 4.7.9 #78 and #82 are
  refuted over ℝ and ℂ at `x = π` (50 proved, 254 refuted and one unproved
  over ℝ). All 305 transcriptions are faithful to v0.1.
- Report `b96dae79…`: the v1 set has 303 rules; seven rewritings into a
  residual integral (1.1.1.2 #2, 1.1.1.3 #50, 3.1.4 #1, 3.1.5 #2, 3.3 #21,
  1.1.3.7 #11, #18) are proved over ℝ and ℂ (50 proved, 252 refuted and one
  unproved over ℝ). All 303 transcriptions are faithful to v0.1.
- Report `22741da9…`: the v1 set has 296 rules; 1.1.3.2 #68 (by parts) is
  proved over ℝ and ℂ (43 proved, 252 refuted and one unproved over ℝ). All
  296 transcriptions are faithful to v0.1.
- Report `c6220e09…`: the v1 set has 295 rules; 1.1.1.2 #4 is proved over ℝ
  and ℂ, 3.2.1 #7 and 4.7.8 #47, #48 are refuted (42 proved, 252 refuted and
  one unproved over ℝ). All 295 transcriptions are faithful to v0.1.
- Report `0a089a2f…`: the v1 set has 291 rules; 108 rules with `EqQ`
  conditions (`relation1#eq`) are refuted over ℝ, 102 also over ℂ (41
  proved, 249 refuted and one unproved over ℝ). All 291 transcriptions are
  faithful to v0.1.
- `scripts/v1_faithfulness.py` maps `EqQ[a, b]` to the OSR v1 condition
  `relation1#eq(a, b)` (Specification V1-R-005).
- Report `5bddaed2…`: the v1 set has 183 rules; the quartic reduction
  1.2.2.1 #4 is proved over ℝ and ℂ (41 proved, 141 refuted and one unproved
  over ℝ). All 183 transcriptions are faithful to v0.1.
- Report `65358b60…`: the v1 set has 182 rules; 1.2.2.2 #19 is refuted over
  ℝ and 3.1.4 #11 over ℝ and ℂ (40 proved, 141 refuted and one unproved
  over ℝ). All 182 transcriptions are faithful to v0.1.
- Report `64f0e4b1…`: the v1 set has 180 rules; the quadratic reductions
  1.2.1.1 #7 and 1.2.1.2 #11 are proved over ℝ and ℂ (40 proved, 139
  refuted and one unproved over ℝ). All 180 transcriptions are faithful to v0.1.
- Report `a956c4cc…`: the v1 set has 178 rules; 4.1.12 #53 and #54 are
  refuted over ℝ and ℂ (their results divide by `b`, which the conditions
  allow to vanish). All 178 transcriptions are faithful to v0.1.
- Report `029e916d…`: the v1 set has 176 rules; 4.1.12 #47 and #48 are
  proved over ℝ and ℂ (38 proved, 137 refuted and one unproved over ℝ).
  All 176 transcriptions are faithful to v0.1.
- Report `d53ec774…`: the v1 set has 174 rules; 4.7.8 #3 and #4 are
  proved over ℝ and 3.1.4 #16 over ℝ and ℂ (36 proved, 137 refuted and
  one unproved over ℝ). All 174 transcriptions are faithful to v0.1.
- Report `0a34c711…`: the v1 set has 171 rules. Two logarithmic rules
  (3.1.3 #8, 3.1.5 #24) are proved over ℝ and unproved over ℂ; 33 proved,
  137 refuted and one unproved over ℝ. All 171 transcriptions are faithful
  to v0.1.
- Report `9705f0ef…`: the v1 set has 169 rules. Four backlog rules
  (3.1.5 #15; 4.1.12 #35, #36; 4.7.9 #71) are proved over ℝ and ℂ; 31
  proved, 137 refuted and one unproved over ℝ. All 169 transcriptions are
  faithful to v0.1.
- Report `29465fa3…`: the v1 set has 165 rules. Nine more (1.2.2.1 #5;
  2.3 #23, #26, #35; 3.1.1 #3; 3.1.4 #9, #17; 3.1.5 #16; 3.3 #12) are
  refuted over ℝ and ℂ; 27 proved, 137 refuted and one unproved over ℝ.
  All 165 transcriptions are faithful to v0.1.
- Report `577cca61…`: the v1 set has 156 rules. Five binomial rules
  (1.1.3.1 #5; 4.1.11 #7, #8, #19, #20) are proved over ℝ and ℂ and 28
  more are refuted in both domains; 27 proved, 128 refuted and one
  unproved over ℝ. All 156 transcriptions are faithful to v0.1.
- Five further RUBI 4.16.1 rules refuted over ℝ and ℂ: 1.2.2.4 #57 and #58,
  2.1 #10, and 4.1.12 #45 and #46. Report `a8eff8f4…` brings the v1 set to 123 rules, with
  22 proved, 100 refuted and one unproved over ℝ; the original conditions
  are preserved and checked against the v0.1 corpus.
- `scripts/v1_faithfulness.py`, with tests: every v1 rule is compared with the
  OpenMath objects its v0.1 rule converts to under the documented conventions;
  `check-v1.sh` and CI run it.
- `docs/known-issues.md` §4: `E`, `ImaginaryI` and `Pi` are converted as free
  names without semantics (630 rules); the inventory now reports atoms a
  pattern does not bind (`rules_by_unbound_atom`) and excludes their rules.
- 105 RUBI rules with residual integrals in `v1/`, from Verification reports
  `4efb181a…`, `aca727e3…`, `a6036490…`, `5c32f229…` and `dfde2079…`: their results contain `int(λx. H)(x)` (Specification
  V1-E-002b) and hold for every choice of antiderivatives of the residual
  integrands; seventeen are proved and 88 refuted (most refutations proposed by a numerical search and proved in Lean). The `Specification`
  submodule advances to `791742d`.
- The inventory maps `NeQ`, `GtQ`, `LtQ`, `IntegerQ`, `IntegersQ`, `IGtQ` and
  `ILtQ` to the conditions of the fragment and reports the candidates with
  such conditions (twenty in all); `v1/` gains the seven migrated rules with
  `NeQ` conditions, from Verification report `be6f672a…`.
- OSR v1 files in `v1/` (`integration.osr.json` and its reports), generated
  by `OpenSymbolicRules/Lean` and published by Verification report
  `68dfb6f0…`: of the nine `FreeQ`-only rules with registered heads, two are
  proved, four are refuted by Lean counterexamples and three are not
  migrated.  `scripts/check-v1.sh` and a CI job check them.
- `scripts/inventory_v1.py`, a deterministic syntactic inventory of the
  migration candidates, with tests.
- A `justfile` with the `check`, `validate`, `test`, `v1`, `update-v1` and
  `inventory` entry points.

### Changed
- The converter maps the reciprocal, hyperbolic and inverse functions to
  their OpenMath `transc1` symbols (`Cot`, `Sec`, `Csc`, `Sinh` … `Csch`,
  `Asin` … `Acsc`, `Asinh` … `Acsch`) and `Abs` to `arith1#abs`, instead of
  `osr#<head>`; the 113 rule files that use them are regenerated (only their
  `semantics` blocks change).
- `scripts/v1_faithfulness.py` reads `Sqrt[a]` as `root(a, 2)`, and
  `scripts/inventory_v1.py` counts `EqQ` as an expressible condition.
- The new unit tests of `scripts/test_inventory_v1.py` and
  `scripts/test_v1_faithfulness.py` are defined before `unittest.main()`, so
  they run.
- `scripts/validate.sh` validates the rule and test files with parallel
  `check-jsonschema` processes (`OSR_CHECK_JOBS`, default: all cores): the
  validation takes under three minutes instead of about twenty.
- Refresh the generated OSR v1 files from Lean source digest `dcad68f4…`
  (the calculus rewriter decides closed conditions; this rule set is
  unchanged).
- The `Specification` submodule advances to `a1e5dfb`, which adds the v1
  schemas.
- `.gitignore` admits `justfile` and `v1/`.
- `docs/known-issues.md`, recording defects of the conversion with the
  measurement that found them.

### Fixed
- The converter now derives a rule file's `semantics` block from its
  constraints as well as its patterns and results. A constraint applies its
  predicates to mathematical expressions, so utility heads such as `Coeff`,
  `Expon`, `Denominator`, `Simplify`, and `PolynomialRemainder` were left
  undeclared in 37 of the 188 rule files and rejected by a host loader.
- The converter no longer declares an OpenMath symbol for a structural head of
  the expression language (`List`) or for a wildcard in operator position
  (`F_`, `G_`, `H_`); neither denotes a mathematical operation.

  Every one of the 188 rule files now satisfies OpenMath semantic closure, and
  all 6,257 rules compile in `OpenSymbolicRules.jl`.

### Added

- Documented backend-neutral integration architecture: ordered RUBI profiles
  complement procedural Risch-family integration, with verification and
  backend provenance retained by the host.
- Required `domain` and `title` manifest fields for the Integration profile.

- `semantics` block in `rule-file.schema.json` to map local functions to OpenMath Content Dictionaries for unambiguous semantics
- A stable `identity` for every generated rule file. Together with its local
  rule `id`, it identifies each of the 6,257 rules across the full profile.
- Cross-file identity validation in `scripts/validate.sh` and CI.
- Exact duplicate-rule baseline validation in CI. The baseline records all
  359 legacy Rubi duplicate groups and rejects new or altered groups.
- Machine-readable Rubi provenance for every converted rule.
- Run the converter drift check for generated rules, tests, and Specification
  updates, using Julia 1.13.
- EARS specification (159 requirements) for OSR v0.1.0-draft
- RFC describing the design rationale and format overview

### Changed
- Updated the Specification submodule to the latest revision, including
  semantic-closure validation and refined transform/proof-trace requirements.
- Parallelized JSON-schema fixture validation in CI in small batches while
  retaining validation of every generated rule and test file.

- Rebranded project to Open Symbolic Rules (OSR) - Integration Module
- Updated README to reflect OSR architecture and OpenMath semantic bridging
- 4 JSON Schema files (draft-07): `osr-expr`, `rule-file`, `test-file`, `meta`
- Sample rule file with 3 linear binomial rules (RUBI Section 1.1.1)
- Sample test fixture file with 3 corresponding test problems
- Load manifest (`rules/meta.json`) with 9-section RUBI taxonomy
- GitHub Actions workflow for CI schema validation
- Local validation script (`validate.sh`)
- Schema validation documentation (`docs/schema-validation.md`)
- Julia-based Mathematica-to-OSR converter (`converter/`)
- Full converted RUBI dataset: 6,257 integration rules in 221 JSON files
- Full converted test suite: 72,523 test problems in 215 JSON files
- Updated `rules/meta.json` manifest with complete load_order (221 entries) and converter metadata
- Predicate catalogue (77 predicates), utility function catalogue (54 + 28 structural), and operator catalogue per EARS spec
- Completed the rename of the format from PIRF to OSR across the RFC, the contribution guide, and the rule manifest

### Fixed

- Emit OpenMath symbols in the `openmath:<cd>#<symbol>` spelling required by `rule-file.schema.json`, so every converted rule file now validates
- Preserve alphanumeric RUBI section labels such as `1.1.2.x` and `7.1.4a`
  instead of truncating them during conversion.
- Map RUBI's `Int` to `openmath:calculus1#int` and its `Log` to `openmath:transc1#ln`: `Int` is an indefinite integral, and `Log` is the natural logarithm rather than OpenMath's base-taking `log`
- Assert the `expression` and `expected_result` field names that `test-file.schema.json` defines in the converter's test-tuple test
