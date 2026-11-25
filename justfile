# Entry points for the Integration (RUBI) rule set.

# Everything CI runs, except the comparison with a Verification report.
check: validate test v1

# Validate the v0.1 schemas, rules, test fixtures and identities.
validate:
	bash scripts/validate.sh

# Unit tests of the repository scripts.
test:
	python3 scripts/test_rubi_release.py
	python3 scripts/test_cas_supplement.py
	python3 scripts/test_bessel_supplement.py
	python3 supplements/cylinder-regressions/check.py
	python3 supplements/maxima/check.py
	python3 scripts/test_post_rubi_examples.py
	python3 scripts/test_rubi_errata.py
	python3 scripts/test_check_duplicate_rules.py
	python3 scripts/test_audit_rubi_order.py
	python3 scripts/test_audit_rubi_coverage.py
	python3 scripts/test_compare_rubi_loaders.py
	python3 scripts/test_check_unknown_heads.py
	python3 scripts/check_unknown_heads.py rules
	python3 scripts/test_inventory_v1.py
	python3 scripts/test_source_verification_status.py
	python3 scripts/test_recovered_profile.py
	python3 -m unittest discover -s scripts -p test_merge_source_edition.py
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

# Compare source definition counts and loaded OSR entries without modifying either tree.
audit-coverage rubi="vendor/Rubi":
	python3 scripts/audit_rubi_coverage.py {{rubi}} rules

# Compare loader file sequences in two existing RUBI Git revisions.
compare-loaders old new rubi="vendor/Rubi":
	python3 scripts/compare_rubi_loaders.py {{rubi}} {{old}} {{new}}

# Reconcile loaded v0.1 entries with v1 verification (JSON on stdout).
source-status:
	python3 scripts/source_verification_status.py

# Rebuild the reference release into a new directory.
rubi-release output rubi="vendor/Rubi":
	python3 scripts/rubi_release.py "{{rubi}}" "{{output}}"

# Rebuild the per-case source locators, extra reference fields and step conditions.
fixture-index output rubi_tests="vendor/MathematicaSyntaxTestSuite":
	julia --project=converter converter/scripts/fixture-index.jl "{{rubi_tests}}" tests "{{output}}"
