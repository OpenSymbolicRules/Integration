# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
- Parallelized JSON-schema fixture validation in CI while retaining validation
  of every generated rule and test file.

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
