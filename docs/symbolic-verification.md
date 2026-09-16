# Symbolic Verification

The `scripts/verify_tests.jl` script verifies OSR integration test
files by symbolically differentiating each antiderivative and checking
it matches the integrand.

## How It Works

For each test problem `{integrand: f, variable: x, optimal_antiderivative: F}`:

1. Parse `f` and `F` from OSR-Expr JSON into Symbolics.jl expressions
2. Compute `dF/dx` using symbolic differentiation
3. Check if `simplify(dF/dx - f) == 0`
4. If symbolic simplification fails, try numerical spot-check

## Usage

```bash
# Install dependencies (first time)
julia --project=scripts -e 'using Pkg; Pkg.instantiate()'

# Run on section 1.1.1 (default)
julia --project=scripts scripts/verify_tests.jl

# Run on a specific file
julia --project=scripts scripts/verify_tests.jl tests/path/to/file.json
```

## Result Categories

| Result | Meaning |
|--------|---------|
| PASS | `d/dx(antiderivative) == integrand` verified |
| FAIL | Derivative does not match integrand (simplification limitation or real mismatch) |
| SKIP | Test uses unsupported operators (special functions, complex numbers) or `num_steps < 0` |
| ERROR | Unexpected exception during verification |

## Proof-of-Concept Results

Tested on Section 1.1.1 (linear binomial products):

| File | Tests | Pass | Fail | Skip | Verifiable Rate |
|------|-------|------|------|------|-----------------|
| 1.1.1.2 | 1,971 | 1,580 | 46 | 345 | 97.2% |
| 1.1.1.5 | 34 | 28 | 0 | 6 | 100% |

Most "fail" results are due to Symbolics.jl simplification limitations
rather than actual conversion errors.

## Limitations

- **Special functions**: Elliptic integrals, hypergeometric functions,
  Bessel functions, etc. are skipped (not supported by Symbolics.jl).
- **Complex numbers**: Tests involving `ImaginaryI` are skipped.
- **Performance**: Some expressions cause `simplify()` to hang.
  A per-test timeout is not yet implemented.
- **Simplification**: Symbolics.jl's simplifier may not reduce all
  correct expressions to zero, causing false "fail" results.

## Dependencies

- Julia 1.10+
- JSON3.jl
- Symbolics.jl
