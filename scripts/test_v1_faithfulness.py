#!/usr/bin/env python3
"""Regression tests for the v0.1 → v1 faithfulness check."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("v1_faithfulness.py")
SEM = {"Int": "openmath:calculus1#int", "Multiply": "openmath:arith1#times",
       "Add": "openmath:arith1#plus", "Power": "openmath:arith1#power",
       "Sin": "openmath:transc1#sin"}


def oms(cd, name):
    return {"kind": "OMS", "cd": cd, "name": name}


def oma(cd, name, *args):
    return {"kind": "OMA", "applicant": oms(cd, name), "arguments": list(args)}


def omv(n):
    return {"kind": "OMV", "name": n}


def lam(body):
    return {"kind": "OMBIND", "binder": oms("fns1", "lambda"), "variables": [omv("x")],
            "object": body}


class FaithfulnessTests(unittest.TestCase):
    def run_check(self, v1_rule):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "rules").mkdir()
            rule = {"id": 1, "pattern": ["Int", ["Multiply", "a_", "b.", ["Sin", "x_"]], "x_symbol"],
                    "result": ["Add", ["Multiply", "a", "b", "x"], ["Int", ["Sin", "x"], "x"]],
                    "constraints": [["FreeQ", ["List", "a", "b"], "x"], ["NeQ", "a", 0],
                                    ["LtQ", "b", 1]]}
            (root / "rules" / "f.json").write_text(json.dumps(
                {"identity": "rubi:t", "semantics": SEM, "rules": [rule]}))
            (root / "v1.json").write_text(json.dumps({"rules": [v1_rule]}))
            return subprocess.run(
                [sys.executable, str(SCRIPT), "--rules", str(root / "rules"), str(root / "v1.json")],
                capture_output=True, text=True)

    def good(self):
        sin_x = oma("transc1", "sin", omv("x"))
        hole = {"kind": "OMA", "applicant": oma("calculus1", "int", lam(sin_x)),
                "arguments": [omv("x")]}
        return {
            "id": "t", "legacy_id": "rubi:t:1",
            "pattern": oma("calculus1", "int", lam(
                oma("arith1", "times", oma("arith1", "times", omv("a"), omv("b")), sin_x))),
            "replacement": lam(oma("arith1", "plus", oma("arith1", "times",
                oma("arith1", "times", omv("a"), omv("b")), omv("x")), hole)),
            "conditions": [oma("relation1", "neq", omv("a"), {"kind": "OMI", "integer": 0}),
                           oma("relation1", "gt", {"kind": "OMI", "integer": 1}, omv("b"))],
            "independent": [{"variable": "b", "of": "x"}, {"variable": "a", "of": "x"}],
        }

    def test_faithful_rule_passes(self):
        result = self.run_check(self.good())
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("1 faithful", result.stdout)

    def test_right_nested_product_is_reported(self):
        rule = self.good()
        rule["pattern"] = oma("calculus1", "int", lam(oma("arith1", "times", omv("a"),
            oma("arith1", "times", omv("b"), oma("transc1", "sin", omv("x"))))))
        result = self.run_check(rule)
        self.assertEqual(result.returncode, 1)
        self.assertIn("pattern differs", result.stdout)

    def test_missing_condition_is_reported(self):
        rule = self.good()
        rule["conditions"] = rule["conditions"][:1]
        result = self.run_check(rule)
        self.assertEqual(result.returncode, 1)
        self.assertIn("conditions differ", result.stdout)

    def test_independence_is_compared(self):
        rule = self.good()
        rule["independent"] = [{"variable": "a", "of": "x"}]
        result = self.run_check(rule)
        self.assertEqual(result.returncode, 1)
        self.assertIn("independent differs", result.stdout)


class DocumentedIndependenceTests(FaithfulnessTests):
    def test_extra_independence_needs_a_finding(self):
        rule = self.good()
        rule["independent"].append({"variable": "z", "of": "x"})
        self.assertEqual(self.run_check(rule).returncode, 1)
        rule["findings"] = ["independence: z is declared independent of x because …"]
        result = self.run_check(rule)
        self.assertEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main()
