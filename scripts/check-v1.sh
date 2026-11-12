#!/usr/bin/env bash
# Check the generated OSR v1 files in v1/.
#
# Usage: scripts/check-v1.sh [<Verification report directory>]
#
# 1. the rule set validates against the v1 schema of the Specification
#    submodule;
# 2. the rule set and the report come from the same Lean source digest;
# 3. with a report directory, every file in v1/ is byte-identical to the
#    published verification report.
set -euo pipefail

name=integration
files=("$name.osr.json" "$name.report.json" "$name.report.md")

cd "$(dirname "$0")/.."

check-jsonschema --schemafile Specification/schemas/v1/ruleset.schema.json \
  "v1/$name.osr.json"

python3 - "$name" <<'PY'
import json
import sys

name = sys.argv[1]
ruleset = json.load(open(f"v1/{name}.osr.json"))
report = json.load(open(f"v1/{name}.report.json"))
a = ruleset["build"]["source_digest"]
b = report["build"]["source_digest"]
if a != b:
    sys.exit(f"source digest mismatch: rule set {a}, report {b}")
digest = a.removeprefix("sha256:")
if digest not in open(f"v1/{name}.report.md").read():
    sys.exit(f"{name}.report.md does not mention the source digest {digest}")
print(f"v1/: {len(ruleset['rules'])} rules, source digest {a}")
PY

if [ $# -ge 1 ]; then
  status=0
  for f in "${files[@]}"; do
    if cmp -s "v1/$f" "$1/$f"; then
      echo "identical: $f"
    else
      echo "DIFFERENT: $f" >&2
      status=1
    fi
  done
  exit $status
fi
