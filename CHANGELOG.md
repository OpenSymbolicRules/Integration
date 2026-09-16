# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `semantics` block in `rule-file.schema.json` to map local functions to OpenMath Content Dictionaries for unambiguous semantics
- EARS specification (159 requirements) for PIRF v0.1.0-draft
- RFC describing the design rationale and format overview

### Changed

- Rebranded project to Open Symbolic Rules (OSR) - Integration Module
- Updated README to reflect OSR architecture and OpenMath semantic bridging
- 4 JSON Schema files (draft-07): `pirf-expr`, `rule-file`, `test-file`, `meta`
- Sample rule file with 3 linear binomial rules (RUBI Section 1.1.1)
- Sample test fixture file with 3 corresponding test problems
- Load manifest (`rules/meta.json`) with 9-section RUBI taxonomy
- GitHub Actions workflow for CI schema validation
- Local validation script (`validate.sh`)
- Schema validation documentation (`docs/schema-validation.md`)
- Julia-based Mathematica-to-PIRF converter (`converter/`)
- Full converted RUBI dataset: 6,257 integration rules in 221 JSON files
- Full converted test suite: 72,523 test problems in 215 JSON files
- Updated `rules/meta.json` manifest with complete load_order (221 entries) and converter metadata
- Predicate catalogue (77 predicates), utility function catalogue (54 + 28 structural), and operator catalogue per EARS spec
