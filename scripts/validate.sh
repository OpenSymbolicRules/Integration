#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== OSR Schema Validation ==="
echo ""

# Step 1: Validate schemas themselves
echo "Step 1/4: Validating schemas against JSON Schema meta-schema..."
check-jsonschema --check-metaschema Specification/schemas/*.schema.json
echo "  PASS"

# Step 2: Validate meta.json
echo "Step 2/4: Validating rules/meta.json..."
check-jsonschema --schemafile Specification/schemas/meta.schema.json rules/meta.json
echo "  PASS"

# Step 3: Validate rule files
echo "Step 3/4: Validating rule files..."
RULE_FILES=$(find rules/ -name '*.json' ! -name 'meta.json' 2>/dev/null || true)
if [ -n "$RULE_FILES" ]; then
  check-jsonschema \
    --schemafile Specification/schemas/rule-file.schema.json \
    --base-uri "file://${PWD}/Specification/schemas/" \
    $RULE_FILES
  echo "  PASS"
else
  echo "  SKIP (no rule files found)"
fi

# Step 4: Validate test files
echo "Step 4/4: Validating test files..."
TEST_FILES=$(find tests/ -name '*.json' 2>/dev/null || true)
if [ -n "$TEST_FILES" ]; then
  check-jsonschema \
    --schemafile Specification/schemas/test-file.schema.json \
    --base-uri "file://${PWD}/Specification/schemas/" \
    $TEST_FILES
  echo "  PASS"
else
  echo "  SKIP (no test files found)"
fi

echo ""
echo "=== All validations passed ==="
