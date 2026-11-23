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

# Update meta.json with load_order, counts, and converter metadata
julia --project=converter converter/scripts/convert.jl --manifest

# Convert a single .m file
julia --project=converter converter/scripts/convert.jl path/to/file.m
```

Notebook-generated RUBI files are parsed as complete `::Code::` cells, not
individual lines. Files containing RUBI `Star` or other unsupported syntax
or local bindings whose behavior has not been audited are reported and not
converted. A batch conversion stages its output and
fails without changing the destination if any file reports a warning. This
does not resolve all empty files; see [known issues](../docs/known-issues.md).
The legacy one-expression-per-line path still needs a separate loss audit.
Run the manifest update only after reviewing a complete conversion: the
existing manifest generator sorts by file path, and does not reproduce the
load sequence in RUBI's `Rubi.m`.

## Output

- **Rules**: `rules/` directory — 221 JSON files containing 6,257 integration rules
- **Tests**: `tests/` directory — 215 JSON files containing 72,523 test problems
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
