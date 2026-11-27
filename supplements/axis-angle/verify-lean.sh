#!/usr/bin/env bash
# Replay the source checks and real proofs with the Verification report's toolchain.
set -euo pipefail
suite=$(cd "$(dirname "$0")" && pwd)
project=$(cd "${1:?pass the prepared OSR Lean project or Mathlib checkout}" && pwd)
report="$suite/../../v1/integration.report.json"
mathlib="$project"
if [[ -d "$project/.lake/packages/mathlib" ]]; then
    mathlib="$project/.lake/packages/mathlib"
fi
revision=$(jq -er '.build.mathlib_revision' "$report")
toolchain=$(jq -er '.build.lean_toolchain' "$report")
if [[ $(git -C "$mathlib" rev-parse HEAD) != "$revision" || $(cat "$project/lean-toolchain") != "$toolchain" ]]; then
    echo "Expected Mathlib $revision and toolchain $toolchain from $report" >&2
    exit 1
fi
python3 "$suite/check.py"
cd "$project"
version=$(lake env lean --version)
if [[ "$version" != "Lean (version ${toolchain##*:v},"* ]]; then
    echo "Unexpected Lean executable: $version" >&2
    exit 1
fi
lake env lean -DwarningAsError=true "$suite/AxisAngle.lean"
