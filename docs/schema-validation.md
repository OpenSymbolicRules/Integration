# JSON Schema Validation

OSR uses JSON Schema (draft-07) to enforce the structure of all rule
files, test fixtures, and the load manifest. Four schemas validate the
project's JSON data files.

## Schema Files

| Schema | Validates | Location |
|--------|-----------|----------|
| `osr-expr.schema.json` | Shared expression type (referenced by others) | `schemas/` |
| `rule-file.schema.json` | Rule files in `rules/` | `schemas/` |
| `test-file.schema.json` | Test fixtures in `tests/` | `schemas/` |
| `meta.schema.json` | `rules/meta.json` manifest | `schemas/` |

## Local Validation

### Install

```bash
pip install check-jsonschema
```

### Validate All Files

```bash
scripts/validate.sh
```

This runs six validation steps and reports pass/fail for each. The fifth
step verifies that each `identity:id` pair is unique across the complete rule
profile; this cross-file invariant cannot be expressed by JSON Schema alone.

The final step verifies the exact duplicate-rule baseline. It fingerprints the
`pattern`, `constraints`, and `result` of each rule, and rejects a new group or
a changed member list. Regenerate the reviewed legacy baseline only after a
conversion update:

```bash
python3 scripts/check_duplicate_rules.py rules \
  --baseline scripts/duplicate-rule-baseline.json --write-baseline
```

### Validate Individual Files

```bash
# Validate a rule file
check-jsonschema \
  --schemafile schemas/rule-file.schema.json \
  --base-uri "file://${PWD}/schemas/" \
  rules/1-algebraic/1.1-binomial/1.1.1-linear/1.1.1.1-\(a+b-x\)^m.json

# Validate meta.json
check-jsonschema --schemafile schemas/meta.schema.json rules/meta.json

# Validate a test file
check-jsonschema \
  --schemafile schemas/test-file.schema.json \
  --base-uri "file://${PWD}/schemas/" \
  tests/1-algebraic/1.1-binomial/1.1.1-linear/1.1.1.1-\(a+b-x\)^m.json

# Verify schemas themselves are valid JSON Schema
check-jsonschema --check-metaschema schemas/*.schema.json
```

### Verbose Output

Add `-v` for detailed error reporting:

```bash
check-jsonschema --schemafile schemas/rule-file.schema.json \
  --base-uri "file://${PWD}/schemas/" \
  rules/1-algebraic/1.1-binomial/1.1.1-linear/1.1.1.1-\(a+b-x\)^m.json -v
```

## Schema-to-Directory Mapping

| Directory | Schema | Notes |
|-----------|--------|-------|
| `rules/meta.json` | `meta.schema.json` | Single file |
| `rules/**/*.json` (excl. meta.json) | `rule-file.schema.json` | Recursive |
| `tests/**/*.json` | `test-file.schema.json` | Recursive |
| `schemas/*.schema.json` | JSON Schema draft-07 meta-schema | Self-validation |

## Cross-File Reference Resolution

The `--base-uri "file://${PWD}/schemas/"` flag is required because
`rule-file.schema.json` and `test-file.schema.json` contain `$ref`
references to `osr-expr.schema.json`. This flag overrides the `$id`
URI (`https://domain.org/schemas/v0.1/...`) to resolve references
against local files.

## CI/CD Enforcement

A GitHub Actions workflow (`.github/workflows/validate-schemas.yml`)
runs schema validation automatically on:

- Every push that modifies `rules/`, `tests/`, or `schemas/`
- Every pull request that modifies those directories

If validation fails, the CI check blocks the merge and reports the
specific file and field that failed.

## Operator and Predicate Enums

The `osr-expr.schema.json` schema contains enum definitions that
document every operator and predicate in the OSR-Expr catalogue.
These enums are for documentation and tooling — the `operator-name`
regex pattern (`^[a-zA-Z$][a-zA-Z0-9$]*$`) is what actually validates
operator names in expressions. The regex accepts both PascalCase
standard operators (e.g., `Sin`, `Add`) and lowercase inert forms
(e.g., `sin`, `cos`) used in RUBI's trig normalization rules.

| Definition | Count | Spec Reference |
|------------|-------|----------------|
| `core-arithmetic-operators` | 9 | OSR-X-010 |
| `trig-operators` | 6 | OSR-X-011 |
| `hyperbolic-operators` | 6 | OSR-X-012 |
| `inverse-trig-operators` | 6 | OSR-X-013 |
| `inverse-hyperbolic-operators` | 6 | OSR-X-014 |
| `exp-log-operators` | 2 | OSR-X-015 |
| `special-function-operators` | 29 | OSR-X-016 |
| `constant-symbols` | 7 | OSR-X-017 |
| `integration-operators` | 7 | OSR-X-018 |
| `utility-function-operators` | 54 | OSR-X-019 (§4.11) |
| `structural-utility-operators` | 28 | OSR-X-020 (§4.12) |
| `predicate-names` | 77 | OSR-C-001 to C-030 (§7) |

## Taxonomy Subsections

The `meta.schema.json` supports optional `subsections` arrays in
taxonomy entries, enabling machine-readable representation of the
full RUBI hierarchy (e.g. Section 1 > 1.1 Binomial products >
1.1.1 Linear). Subsection numbers use dotted string format
(e.g. `"1.1"`, `"1.1.1"`, `"8.10"`).

## Converter Usage

The `converter/` directory contains a Julia tool that converts RUBI's
Mathematica source files to OSR JSON format. See `converter/README.md`
for full documentation.

### Quick Start

```bash
# Initialize git submodules (RUBI source + test suite)
git submodule update --init

# Convert rules, tests, and update manifest
julia --project=converter converter/scripts/convert.jl --rules
julia --project=converter converter/scripts/convert.jl --tests
julia --project=converter converter/scripts/convert.jl --manifest

# Validate all generated files
scripts/validate.sh
```

### Expected Output

| Artifact | Directory | Files | Items |
|----------|-----------|-------|-------|
| Rules | `rules/` | 221 | 6,257 rules |
| Tests | `tests/` | 215 | 72,523 test problems |
| Manifest | `rules/meta.json` | 1 | load_order + counts |

## Updating Schemas

When modifying schemas:

1. Edit the schema file in `schemas/`.
2. Run `check-jsonschema --check-metaschema schemas/*.schema.json` to
   verify the schema is still valid.
3. Run `scripts/validate.sh` to verify existing data files still pass.
4. Commit the schema change alongside any data file changes.
5. Include a migration note in the PR describing impact on consumers.
# Stable rule identities

Every generated rule file includes a stable `identity`.  Combined with a
rule's file-local positive integer `id`, it forms the canonical profile-wide
identifier `identity:id`.  `section` remains a taxonomy label and is not an
identifier.
