#!/usr/bin/env python3
"""Freeze and validate exact duplicate symbolic rules in a profile.

An exact duplicate has the same OSR pattern, constraints, and result.  The
baseline deliberately records all member identities: adding another occurrence
to a legacy duplicate group therefore fails validation instead of being hidden
by an existing fingerprint.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


def canonical_payload(rule: dict[str, Any]) -> str:
    """Return a deterministic representation of the rewrite semantics."""
    payload = {
        "constraints": rule.get("constraints", []),
        "pattern": rule.get("pattern"),
        "result": rule.get("result"),
    }
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"), sort_keys=True)


def duplicate_groups(rules_dir: Path) -> dict[str, list[str]]:
    """Collect exact duplicate groups, keyed by semantic fingerprint."""
    occurrences: dict[str, list[str]] = defaultdict(list)
    for path in sorted(rules_dir.rglob("*.json")):
        if path.name == "meta.json":
            continue
        with path.open(encoding="utf-8") as handle:
            document = json.load(handle)
        identity = document.get("identity")
        if not isinstance(identity, str) or not identity:
            raise ValueError(f"{path}: missing non-empty identity")
        for rule in document.get("rules", []):
            rule_id = rule.get("id")
            if not isinstance(rule_id, int):
                raise ValueError(f"{path}: rule without an integer id")
            fingerprint = hashlib.sha256(canonical_payload(rule).encode()).hexdigest()
            occurrences[fingerprint].append(f"{identity}:{rule_id}")
    return {
        fingerprint: sorted(members)
        for fingerprint, members in occurrences.items()
        if len(members) > 1
    }


def baseline_document(groups: dict[str, list[str]]) -> dict[str, Any]:
    return {"version": 1, "duplicate_groups": groups}


def read_baseline(path: Path) -> dict[str, list[str]]:
    with path.open(encoding="utf-8") as handle:
        document = json.load(handle)
    if document.get("version") != 1 or not isinstance(document.get("duplicate_groups"), dict):
        raise ValueError(f"{path}: unsupported duplicate-rule baseline")
    groups = document["duplicate_groups"]
    if not all(isinstance(key, str) and isinstance(value, list) for key, value in groups.items()):
        raise ValueError(f"{path}: invalid duplicate-rule baseline groups")
    return {key: sorted(value) for key, value in groups.items()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rules_dir", type=Path)
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--write-baseline", action="store_true")
    arguments = parser.parse_args()

    try:
        actual = duplicate_groups(arguments.rules_dir)
        if arguments.write_baseline:
            arguments.baseline.write_text(
                json.dumps(baseline_document(actual), indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            print(f"Wrote {len(actual)} exact duplicate groups to {arguments.baseline}")
            return 0

        expected = read_baseline(arguments.baseline)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Duplicate-rule validation failed: {error}", file=sys.stderr)
        return 1

    failures: list[str] = []
    for fingerprint in sorted(actual.keys() - expected.keys()):
        failures.append(f"new group {fingerprint}: {', '.join(actual[fingerprint])}")
    for fingerprint in sorted(expected.keys() - actual.keys()):
        failures.append(f"missing baseline group {fingerprint}")
    for fingerprint in sorted(actual.keys() & expected.keys()):
        if actual[fingerprint] != expected[fingerprint]:
            failures.append(
                f"membership changed for {fingerprint}: expected "
                f"{', '.join(expected[fingerprint])}; found {', '.join(actual[fingerprint])}"
            )

    if failures:
        print("Exact duplicate-rule baseline changed:", file=sys.stderr)
        print("\n".join(f"  {failure}" for failure in failures), file=sys.stderr)
        return 1

    print(f"Validated {len(actual)} acknowledged exact duplicate groups")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
