#!/usr/bin/env python3
"""Report fabricated UnknownHead expressions and reject them in loaded rules."""
import json
from pathlib import Path
import sys


def contains_unknown_head(value):
    if isinstance(value, list):
        return bool(value) and (value[0] == "UnknownHead" or any(map(contains_unknown_head, value)))
    if isinstance(value, dict):
        return any(map(contains_unknown_head, value.values()))
    return False


def check(root):
    root = Path(root)
    meta = json.loads((root / "meta.json").read_text())
    order = meta["load_order"]
    if not isinstance(order, list) or any(not isinstance(p, str) for p in order):
        raise ValueError("load_order must be an array of paths")
    for name in order:
        path = Path(name)
        if path.is_absolute() or ".." in path.parts or not (root / path).is_file():
            raise ValueError(f"invalid or missing load_order file: {name}")
    loaded = set(order)
    failures = []
    excluded_files = excluded_rules = 0
    for path in root.rglob("*.json"):
        if path == root / "meta.json":
            continue
        document = json.loads(path.read_text())
        affected = [str(rule.get("id", "?")) for rule in document["rules"] if contains_unknown_head(rule)]
        if not affected:
            continue
        name = path.relative_to(root).as_posix()
        if name in loaded:
            failures.append(f"{name}: rules {', '.join(affected)}")
        else:
            excluded_files += 1
            excluded_rules += len(affected)
    print(f"UnknownHead: {excluded_rules} excluded rules in {excluded_files} files; {len(failures)} loaded files affected")
    for failure in failures:
        print(f"Loaded rule contains fabricated UnknownHead: {failure}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise ValueError("usage: check_unknown_heads.py RULES_DIR")
        sys.exit(check(sys.argv[1]))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"UnknownHead check failed: {error}", file=sys.stderr)
        sys.exit(1)
