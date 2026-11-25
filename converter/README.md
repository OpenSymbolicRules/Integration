# RubiConverter.jl

A Julia-based converter that transforms RUBI's Mathematica `.m` rule files and test suites into the OSR (Portable Integration Rules Format) JSON format.

## Disclaimer

This is a **community conversion tool** and is **not an official product** of the RUBI project or its author Albert Rich. The RUBI integration rules are developed and maintained by Albert Rich under the MIT License. Users should verify converted output against upstream RUBI sources for correctness.

For the official RUBI project, visit: https://rulebasedintegration.org

## Requirements

- Julia 1.10+
- Git submodules initialized (`vendor/Rubi`, `vendor/MathematicaSyntaxTestSuite`)

## Usage

```bash
# Initialize submodules
git submodule update --init

# Convert all RUBI integration rules to OSR JSON
julia --project=converter converter/scripts/convert.jl --rules

# Convert all test problems to OSR JSON
julia --project=converter converter/scripts/convert.jl --tests

# Update meta.json counts and converter metadata, preserving reviewed load_order
julia --project=converter converter/scripts/convert.jl --manifest

# Convert a single .m file
julia --project=converter converter/scripts/convert.jl path/to/file.m

# Audit notebook cells without modifying the rule corpus
julia --project=converter converter/scripts/audit-cells.jl vendor/Rubi > /tmp/rubi-cell-audit.json

# Recover candidates for loaded empty files into a new, isolated directory
julia --project=converter converter/scripts/recover-empty.jl rules vendor/Rubi /tmp/rubi-empty-candidates

# Inspect notebook cells in source order; explicitly select the show-steps branch
julia --project=converter converter/scripts/recover-cells.jl path/to/source.m --show-steps false

# Classify Module syntax in files reported as blocked, without changing them
julia --project=converter converter/scripts/audit-module.jl /tmp/rubi-empty-candidates/report.json vendor/Rubi > /tmp/rubi-module-audit.json
```

Notebook-generated RUBI files are parsed as complete `::Code::` cells, not
individual lines. Files containing RUBI `Star` or other unsupported syntax
or local bindings whose behavior has not been audited are reported and not
converted. A batch conversion stages its output and
fails without changing the destination if any file reports a warning. This
does not resolve all empty files; see [known issues](../docs/known-issues.md).
The legacy one-expression-per-line path still needs a separate loss audit.
The manifest update preserves the existing reviewed load order and rejects
missing or duplicate entries. It does not infer a new order after a source
change; review the source-file sequence separately before changing it.
Use `python3 scripts/audit_rubi_order.py vendor/Rubi rules` to inspect the
source-file sequence and unmatched OSR files without changing the manifest.
The default manifest follows the pinned source's default file sequence; it is
incomplete while loaded rule files remain empty and does not claim to reproduce
Mathematica's final rule priority.

The candidate expression mapping preserves the `Star` operator, whose
mathematical projection is `arith1#times`; this does not make it operationally
interchangeable with ordinary multiplication. `With`/`Set` bindings are
treated as structural in the candidate mapping. File export remains blocked
for both until the specification and consumer capability contract are adopted.
For isolated diagnostics only, `convert_rule_file` accepts the keyword
`experimental_rubi_extensions=true`; the default and batch conversion remain
fail-closed. The experimental output must not be treated as a production
ruleset or as evidence of CAS or Lean verification.
The recovery script attempts the currently loaded empty files, records each
candidate or blocked file in `report.json`, and never modifies `rules/`.
For each generated file it lists the IDs and counts of rules containing
`Star` and `With`. This is a partial syntax inventory: it does not assess
other utilities, pattern behavior, numeric assumptions or engine support.
The output directory must not already exist and must be outside the rule and
vendor trees. It contains experimental candidates, not an executable ruleset:
unsupported operational semantics and consumer capabilities remain to be
reviewed. A blocked entry is not a converted empty rule file.
The cell report records blocked and empty cells rather than dropping them;
blocked entries retain their original text and, when parsing succeeds, a
diagnostic source AST. That AST is not an OSR expression and can reflect
parser numeric limitations; original source text remains authoritative.
its IDs are cell positions, not runtime priorities or published rule IDs.
It preserves candidates only for review and does not modify `rules/`.
The Module audit counts syntax, not semantic validity. Counts of assignments
in nested bodies can overlap; the older line-based parser can omit expressions.

## Output

- **Rules**: `rules/` directory — 221 JSON files containing 6,286 entries,
  including duplicates and empty sections; conversion remains incomplete
- **Tests**: `tests/` directory — 215 JSON files containing 72,584 test problems
- **Manifest**: `rules/meta.json` — load order, counts, and converter metadata

## Validation

All output files are validated against OSR JSON schemas:

```bash
./validate.sh
```

## Architecture

The converter uses a 4-stage pipeline:

1. **Tokenizer** (`src/tokenizer.jl`) — Lexes Mathematica syntax into tokens
2. **Parser** (`src/parser.jl`) — Recursive descent parser producing an AST
3. **Transformer** (`src/transformer.jl`) — Converts AST to OSR-Expr JSON arrays
4. **Writers** (`src/rule_writer.jl`, `src/test_writer.jl`) — Produces complete OSR JSON files

## Running Tests

```bash
julia --project=converter -e 'using Pkg; Pkg.test()'
```

## License

This converter tool is part of the OSR project and is released under the MIT License. The RUBI integration rules themselves are also MIT-licensed by Albert Rich.
