# Entry points for the Integration (RUBI) rule set.

# Everything CI runs, except the comparison with a Verification report.
check: validate test v1

# Validate the v0.1 schemas, rules, test fixtures and identities.
validate:
	./scripts/validate.sh

# Unit tests of the repository scripts.
test:
	python3 scripts/test_check_duplicate_rules.py
	python3 scripts/test_inventory_v1.py
	python3 scripts/test_v1_faithfulness.py

# Check the generated OSR v1 files; pass a Verification report directory to
# also compare them byte for byte.
v1 report="":
	./scripts/check-v1.sh {{report}}

# Copy the v1 files from a Verification report directory, then check them.
update-v1 report:
	cp {{report}}/integration.osr.json {{report}}/integration.report.json {{report}}/integration.report.md v1/
	./scripts/check-v1.sh {{report}}

# Syntactic inventory of the rules for the OSR v1 migration (JSON on stdout).
inventory registry="../OpenMath/registry/registry.json":
	python3 scripts/inventory_v1.py --registry {{registry}}
