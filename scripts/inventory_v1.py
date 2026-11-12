#!/usr/bin/env python3
"""Inventory the RUBI rules for an OSR v1 migration, syntactically.

The inventory counts rules by their top-level constraint predicates and by
the expression heads that the OpenMath registry of OpenSymbolicRules/OpenMath
does not interpret.  A *candidate* has only FreeQ constraints (or none), an
outer binary Int in its pattern, no Int in its result, and only registered
heads once the outer Int is removed.  An *expressible-condition candidate*
may also carry the predicates that map to the conditions of the fragment
(EXPRESSIBLE), with registered heads in their arguments.

These counts establish neither migratability nor correctness: conditions,
domains, literal encodings, arities, optional wildcards and binding closure
still need review, rule by rule.

Usage: scripts/inventory_v1.py --registry <registry.json> [--rules rules] [--no-commit]
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess
import sys

OPENMATH = "http://www.openmath.org/cd/"

# RUBI predicates with a counterpart among the conditions of the OSR v1
# fragment (OSR.Cond: ne, gt over the reals, int):
#   NeQ[a, b] -> a ≠ b          GtQ[a, b] -> a > b      LtQ[a, b] -> b > a
#   IntegerQ[a], IntegersQ[a, …] -> a ∈ ℤ, …
#   IGtQ[n, k] -> n ∈ ℤ ∧ n > k  ILtQ[n, k] -> n ∈ ℤ ∧ k > n
# Mathematica evaluates them on the matched expressions (IntegerQ tests for an
# integer literal, NeQ for a value not possibly zero), so the conditions are a
# semantic reading of the predicates, to be reviewed rule by rule.
EXPRESSIBLE = {"FreeQ", "NeQ", "GtQ", "LtQ", "IntegerQ", "IntegersQ", "IGtQ", "ILtQ"}


def heads(term):
    """Heads of every compound subterm."""
    if not isinstance(term, list) or not term:
        return set()
    result = {term[0]} if isinstance(term[0], str) else set()
    for child in term[1:]:
        result |= heads(child)
    return result


def ranked(counter):
    return dict(sorted(counter.items(), key=lambda item: (-item[1], item[0])))


def expressible(constraint, registered_head) -> bool:
    """A constraint with a fragment counterpart and registered argument heads."""
    if not (isinstance(constraint, list) and constraint and constraint[0] in EXPRESSIBLE):
        return False
    if constraint[0] == "FreeQ":
        return True
    return all(registered_head(h) for arg in constraint[1:] for h in heads(arg))


def inventory(rules_dir: Path, registry_path: Path) -> dict:
    registry = json.loads(registry_path.read_text())
    registered = {s["uri"] for s in registry["symbols"]}
    predicates, unsupported, counts = Counter(), Counter(), Counter()
    candidates, conditional = [], []
    conditional_predicates = Counter()
    source = hashlib.sha256()
    for path in sorted(rules_dir.rglob("*.json")):
        if path.name == "meta.json":
            continue
        relative = path.relative_to(rules_dir.parent).as_posix()
        source.update(relative.encode() + b"\0" + path.read_bytes() + b"\0")
        document = json.loads(path.read_text())
        rules = document.get("rules", [])
        if rules:
            counts["nonempty_rule_files"] += 1
        semantics = document.get("semantics", {})

        def registered_head(head, semantics=semantics):
            return semantics.get(head, "").replace("openmath:", OPENMATH) in registered
        for rule in rules:
            counts["rules"] += 1
            constraints = rule.get("constraints", [])
            guard_heads = {c[0] for c in constraints if isinstance(c, list) and c}
            predicates.update(guard_heads)
            if not constraints:
                counts["unconditional_rules"] += 1
            freeq_only = guard_heads <= {"FreeQ"}
            if freeq_only:
                counts["only_freeq_or_unconditional"] += 1
            conditions_ok = all(expressible(c, registered_head) for c in constraints)
            if conditions_ok:
                counts["expressible_conditions"] += 1
            pattern = rule.get("pattern")
            if not (isinstance(pattern, list) and len(pattern) == 3 and pattern[0] == "Int"):
                counts["without_binary_int_wrapper"] += 1
                continue
            result_heads = heads(rule.get("result"))
            missing = {
                head for head in heads(pattern[1]) | result_heads if not registered_head(head)
            }
            unsupported.update(missing)
            recursive = "Int" in result_heads
            if recursive:
                counts["recursive_integral_in_result"] += 1
            if not missing:
                counts["heads_in_current_registry"] += 1
                entry = {
                    "legacy_id": f"{document.get('identity', path.stem)}:{rule.get('id')}",
                    "file": relative,
                }
                if freeq_only and not recursive:
                    candidates.append(entry)
                if conditions_ok and not recursive:
                    conditional.append(entry)
                    conditional_predicates.update(guard_heads)
    return {
        "rules_sha256": source.hexdigest(),
        "registry_sha256": hashlib.sha256(registry_path.read_bytes()).hexdigest(),
        "scope": (
            "Syntactic inventory only. Int is removed from the pattern before comparing "
            "heads with the registry; a candidate has no Int in its result. Counts do not "
            "establish migratability, correctness or certification."
        ),
        "counts": dict(sorted(counts.items())),
        "rules_by_top_level_predicate": ranked(predicates),
        "rules_by_unregistered_expression_head": ranked(unsupported),
        "registered_heads_and_only_freeq_candidates": candidates,
        "expressible_condition_candidates_by_predicate": ranked(conditional_predicates),
        "registered_heads_and_expressible_condition_candidates": conditional,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    root = Path(__file__).resolve().parent.parent
    parser.add_argument("--rules", type=Path, default=root / "rules")
    parser.add_argument("--registry", type=Path, required=True,
                        help="registry.json of OpenSymbolicRules/OpenMath")
    parser.add_argument("--no-commit", action="store_true",
                        help="omit the Git commit of the repository")
    args = parser.parse_args(argv)
    report = inventory(args.rules, args.registry)
    if not args.no_commit:
        commit = subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
        report = {"integration_commit": commit, **report}
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
