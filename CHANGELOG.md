# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
