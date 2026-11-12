#!/usr/bin/env python3
"""Regression tests for the OSR v1 migration inventory."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("inventory_v1.py")
SEMANTICS = {
    "Int": "openmath:calculus1#int",
    "Log": "openmath:transc1#ln",
    "Power": "openmath:arith1#power",
    "Subst": "openmath:osr#Subst",
}
REGISTRY = {
    "symbols": [
        {"uri": "http://www.openmath.org/cd/transc1#ln"},
        {"uri": "http://www.openmath.org/cd/arith1#power"},
    ]
}


def rule(rule_id, pattern, result, constraints=()):
    return {"id": rule_id, "pattern": pattern, "result": result,
            "constraints": list(constraints)}


class InventoryTests(unittest.TestCase):
    def run_inventory(self, rules, registry=REGISTRY):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "rules").mkdir()
            document = {"identity": "rubi:test", "semantics": SEMANTICS, "rules": rules}
            (root / "rules" / "a.json").write_text(json.dumps(document))
            (root / "rules" / "empty.json").write_text(json.dumps({"rules": []}))
            (root / "registry.json").write_text(json.dumps(registry))
            out = subprocess.run(
                [sys.executable, str(SCRIPT), "--rules", str(root / "rules"),
                 "--registry", str(root / "registry.json"), "--no-commit"],
                check=True, capture_output=True, text=True).stdout
            return json.loads(out)

    def test_candidate_needs_registered_heads_and_only_freeq(self):
        report = self.run_inventory([
            rule(1, ["Int", ["Power", "x_", -1], "x_symbol"], ["Log", "x"]),
            rule(2, ["Int", ["Log", "x_"], "x_symbol"], ["Log", "x"],
                 [["FreeQ", "a", "x"], ["EqQ", "a", 0]]),
            rule(3, ["Int", ["Log", "x_"], "x_symbol"], ["Subst", "x", "x", "x"],
                 [["FreeQ", "a", "x"]]),
        ])
        self.assertEqual(report["counts"]["rules"], 3)
        self.assertEqual(report["counts"]["nonempty_rule_files"], 1)
        self.assertEqual(report["counts"]["unconditional_rules"], 1)
        self.assertEqual(report["counts"]["only_freeq_or_unconditional"], 2)
        self.assertEqual(report["counts"]["heads_in_current_registry"], 2)
        self.assertEqual(
            [c["legacy_id"] for c in report["registered_heads_and_only_freeq_candidates"]],
            ["rubi:test:1"])
        self.assertEqual(report["rules_by_unregistered_expression_head"], {"Subst": 1})
        self.assertEqual(report["rules_by_top_level_predicate"], {"EqQ": 1, "FreeQ": 2})

    def test_recursive_integral_is_counted_and_unregistered(self):
        report = self.run_inventory([
            rule(1, ["Int", ["Log", "x_"], "x_symbol"], ["Int", ["Log", "x"], "x"]),
        ])
        self.assertEqual(report["counts"]["recursive_integral_in_result"], 1)
        self.assertEqual(report["counts"].get("heads_in_current_registry", 0), 0)
        self.assertEqual(report["rules_by_unregistered_expression_head"], {"Int": 1})

    def test_recursive_rule_is_never_a_candidate(self):
        registry = {"symbols": REGISTRY["symbols"] + [{"uri": "http://www.openmath.org/cd/calculus1#int"}]}
        report = self.run_inventory([
            rule(1, ["Int", ["Log", "x_"], "x_symbol"], ["Int", ["Log", "x"], "x"]),
        ], registry)
        self.assertEqual(report["counts"]["heads_in_current_registry"], 1)
        self.assertEqual(report["registered_heads_and_only_freeq_candidates"], [])

    def test_conditions_expressible_in_the_fragment(self):
        report = self.run_inventory([
            rule(1, ["Int", ["Power", "x_", "n_"], "x_symbol"], ["Log", "x"],
                 [["FreeQ", "n", "x"], ["IGtQ", "n", 0]]),
            rule(2, ["Int", ["Power", "x_", "n_"], "x_symbol"], ["Log", "x"],
                 [["FreeQ", "n", "x"], ["NeQ", ["Power", "n", 2], 1], ["LtQ", "n", 0]]),
            rule(3, ["Int", ["Power", "x_", "n_"], "x_symbol"], ["Log", "x"],
                 [["EqQ", "n", 0]]),
            rule(4, ["Int", ["Power", "x_", "n_"], "x_symbol"], ["Log", "x"],
                 [["NeQ", ["Subst", "n", "n", "n"], 0]]),
            rule(5, ["Int", ["Power", "x_", "n_"], "x_symbol"], ["Log", "x"],
                 [["IntegersQ", "n", "m"], ["GtQ", "n", "m"]]),
        ])
        self.assertEqual(
            [c["legacy_id"] for c in report["registered_heads_and_expressible_condition_candidates"]],
            ["rubi:test:1", "rubi:test:2", "rubi:test:5"])
        self.assertEqual(report["counts"]["expressible_conditions"], 3)
        self.assertEqual(
            report["expressible_condition_candidates_by_predicate"],
            {"FreeQ": 2, "GtQ": 1, "IGtQ": 1, "IntegersQ": 1, "LtQ": 1, "NeQ": 1})

    def test_output_is_deterministic(self):
        rules = [rule(1, ["Int", ["Power", "x_", -1], "x_symbol"], ["Log", "x"])]
        self.assertEqual(self.run_inventory(rules), self.run_inventory(rules))


if __name__ == "__main__":
    unittest.main()
