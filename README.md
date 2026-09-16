# Open Symbolic Rules - Integration (formerly PIRF)

[![Validate JSON Schemas](https://github.com/OpenSymbolicRules/Integration/actions/workflows/validate-schemas.yml/badge.svg)](https://github.com/OpenSymbolicRules/Integration/actions/workflows/validate-schemas.yml)

> **Note**: This repository has been created with AI assistance.

A language-neutral JSON format with validated JSON Schema to represent
all of [RUBI](https://rulebasedintegration.org/)'s 6,257 symbolic
integration rules and 72,523 test problems, independently of
Mathematica.

## Overview

This repository is the **Integration Module** of the [OpenSymbolicRules](https://github.com/OpenSymbolicRules) standard. 

It defines a JSON interchange format (originally named PIRF) so that any CAS — Julia, Python/SymPy, Java/SymJa, Rust,
JavaScript — can consume RUBI's integration knowledge with a standard
JSON parser. No CAS software required.

By mapping local functions to OpenMath Content Dictionaries, this format ensures zero semantic ambiguity.

The format covers:

- **Rules**: pattern + constraints + result, with wildcard and predicate
  support (6,257 rules in 221 files)
- **Test fixtures**: integrand + variable + optimal antiderivative +
  expected step count (72,523 tests in 215 files)
- **Taxonomy**: RUBI's exact 9-section hierarchy
- **Load manifest**: precise file loading order determining rule priority

## Repository Structure

```
PIRF/
├── schemas/                          # JSON Schema definitions (draft-07)
│   ├── pirf-expr.schema.json         # Shared recursive expression type
│   ├── rule-file.schema.json         # Rule file structure
│   ├── test-file.schema.json         # Test fixture structure
│   └── meta.schema.json              # Load manifest structure
├── rules/                            # Integration rules (221 JSON files)
│   ├── meta.json                     # Load manifest, taxonomy, feature flags
│   └── 1-algebraic/                  # Section-based directory tree
│       └── 1.1-binomial/
│           └── 1.1.1-linear/
│               └── 1.1.1.1-(a+b-x)^m.json
├── tests/                            # Test fixtures (215 JSON files)
│   └── 1-algebraic/
│       └── 1.1-binomial/
│           └── 1.1.1-linear/
│               └── 1.1.1.2-(a+b-x)^m-(c+d-x)^n.json
├── converter/                        # Mathematica-to-PIRF converter (Julia)
│   ├── scripts/convert.jl            # CLI entry point
│   └── src/                          # Tokenizer, parser, transformer, writers
├── scripts/
│   ├── validate.sh                   # Local schema validation script
│   └── count.sh                      # Count rules and tests
├── specifications/
│   └── v0.1.0-draft/
│       └── spec.md                   # EARS specification (159 requirements)
├── rfc.md                            # RFC / design rationale
├── docs/
│   └── schema-validation.md          # Validation documentation
└── .github/workflows/
    └── validate-schemas.yml          # CI schema validation
```

## Quick Start

```bash
# Validate all rule and test files against schemas
pip install check-jsonschema
scripts/validate.sh

# Count rules and tests
scripts/count.sh
```

See [docs/schema-validation.md](docs/schema-validation.md) for details.

## Converter

The `converter/` directory contains a Julia tool that converts RUBI's
Mathematica source files to PIRF JSON format. See
[converter/README.md](converter/README.md) for full documentation.

```bash
# Initialize git submodules (RUBI source + test suite)
git submodule update --init

# Convert rules, tests, and update manifest
julia --project=converter converter/scripts/convert.jl --rules
julia --project=converter converter/scripts/convert.jl --tests
julia --project=converter converter/scripts/convert.jl --manifest
```

## Dataset Summary

| Artifact | Directory | Files | Items |
|----------|-----------|-------|-------|
| Rules | `rules/` | 221 | 6,257 integration rules |
| Tests | `tests/` | 215 | 72,523 test problems |
| Manifest | `rules/meta.json` | 1 | load_order + counts |

## Status

This project is in **v0.1.0-draft**. The full RUBI rule set and test
suite have been converted to PIRF JSON format, with schema validation
enforced by CI.

## References

- [RUBI — Rule-based Integration](https://rulebasedintegration.org/)
- [RUBI 5 on GitHub](https://github.com/RuleBasedIntegration/)
- [MathLive MathJSON](https://mathlive.io/math-json/) — operator name
  alignment
- [OpenMath 2.0](https://openmath.org/) — formal semantics mapping

## License

MIT
