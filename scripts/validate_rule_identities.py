#!/usr/bin/env python3
"""Validate that every rule identity in a profile is globally unique.

A rule is addressed profile-wide by `identity:id` -- its file's identity and
its own local id -- and never by `section:id`, because a section number can be
renumbered while an identity is stable.  Two rules sharing one address would
make any reference to it ambiguous, so this refuses the corpus outright.

File identities are checked for uniqueness too: two files claiming one identity
collide on every rule they hold, and reporting that once is clearer than
reporting it once per rule.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path


def collect(rules_dir: Path) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    """Return the files claiming each file identity, and each rule address."""
    file_identities: dict[str, list[str]] = defaultdict(list)
    rule_addresses: dict[str, list[str]] = defaultdict(list)

    for path in sorted(rules_dir.rglob("*.json")):
        if path.name == "meta.json":
            continue
        with path.open(encoding="utf-8") as handle:
            document = json.load(handle)

        identity = document.get("identity")
        if not isinstance(identity, str) or not identity:
            raise ValueError(f"{path}: missing non-empty identity")
        file_identities[identity].append(str(path))

        for rule in document.get("rules", []):
            rule_id = rule.get("id")
            if not isinstance(rule_id, int):
                raise ValueError(f"{path}: rule without an integer id")
            rule_addresses[f"{identity}:{rule_id}"].append(str(path))

    return file_identities, rule_addresses


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rules_dir", type=Path, help="directory holding the rule files")
    args = parser.parse_args()

    if not args.rules_dir.is_dir():
        print(f"{args.rules_dir}: not a directory", file=sys.stderr)
        return 2

    try:
        file_identities, rule_addresses = collect(args.rules_dir)
    except (ValueError, json.JSONDecodeError) as error:
        print(f"Rule identities could not be read: {error}", file=sys.stderr)
        return 1

    failures: list[str] = []
    for identity, paths in sorted(file_identities.items()):
        if len(paths) > 1:
            failures.append(f"file identity {identity!r} claimed by: {', '.join(paths)}")
    for address, paths in sorted(rule_addresses.items()):
        if len(paths) > 1:
            failures.append(f"rule address {address!r} used in: {', '.join(paths)}")

    if failures:
        print("Rule identities are not globally unique:", file=sys.stderr)
        print("\n".join(f"  {failure}" for failure in failures), file=sys.stderr)
        return 1

    print(
        f"Validated {len(rule_addresses)} globally unique rule identities "
        f"across {len(file_identities)} files"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
