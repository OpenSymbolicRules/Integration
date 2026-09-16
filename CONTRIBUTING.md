# Contributing to Open Symbolic Rules

First off, thank you for considering contributing to Open Symbolic Rules! Every
contribution helps make symbolic integration rules more accessible
across programming languages.

## Code of Conduct

This project and everyone participating in it is governed by the
[Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
By participating, you are expected to uphold this code. Please report
unacceptable behavior to the project maintainers.

## How Can I Contribute?

### Reporting Issues

- Use GitHub Issues to report bugs or suggest enhancements.
- Check existing issues before creating a new one.
- Include as much detail as possible: which file, what error, expected
  vs actual behavior.

### Submitting Changes

1. Fork the repository.
2. Create a feature branch from `main`:
   ```bash
   git checkout -b your-feature-name
   ```
3. Make your changes.
4. Run schema validation locally:
   ```bash
   pip install check-jsonschema
   ./validate.sh
   ```
5. Commit using [Conventional Commits](https://www.conventionalcommits.org/)
   format:
   ```
   feat: add new predicate to operator catalogue
   fix: correct pattern in rule 42
   docs: update schema validation guide
   ```
6. Push and open a Pull Request against `main`.

### Schema Validation

All JSON files must pass schema validation before merge. The CI
pipeline enforces this automatically. Run `./validate.sh` locally
to catch errors before pushing.

See [docs/schema-validation.md](docs/schema-validation.md) for details.

### Adding Rules

When adding or modifying integration rules:

- Place rule files in the correct taxonomy directory under `rules/`.
- Include corresponding test fixtures under `tests/`.
- Update `rules/meta.json` `load_order` to reference new files.
- Ensure all rules have `id`, `pattern`, `constraints`, and `result`.
- Include `description` and `derivation` for readability.

### Modifying Schemas

When modifying JSON Schema files:

- Run `check-jsonschema --check-metaschema schemas/*.schema.json` to
  verify the schema is still valid.
- Ensure existing data files still pass validation.
- Include a migration note in the PR describing impact on consumers.
- Schema changes must follow Semantic Versioning.

## Style Guide

- JSON files: 2-space indentation, no trailing whitespace.
- Operator names: PascalCase (e.g., `Add`, `Sin`, `Power`).
- Wildcard syntax: per the EARS specification (`x_`, `a.`, `m_integer`).
- Commit messages: Conventional Commits format.

## Questions?

Open a GitHub Issue with the `question` label.
