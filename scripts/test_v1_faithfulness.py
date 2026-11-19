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
    def run_check(self, v1_rule, constraints=None):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "rules").mkdir()
            rule = {"id": 1, "pattern": ["Int", ["Multiply", "a_", "b.", ["Sin", "x_"]], "x_symbol"],
                    "result": ["Add", ["Multiply", "a", "b", "x"], ["Int", ["Sin", "x"], "x"]],
                    "constraints": constraints or [["FreeQ", ["List", "a", "b"], "x"], ["NeQ", "a", 0],
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

    def test_eqq_becomes_relation1_eq(self):
        rule = self.good()
        rule["conditions"] = [oma("relation1", "eq", omv("a"), {"kind": "OMI", "integer": 0}),
                              oma("relation1", "gt", {"kind": "OMI", "integer": 1}, omv("b"))]
        constraints = [["FreeQ", ["List", "a", "b"], "x"], ["EqQ", "a", 0], ["LtQ", "b", 1]]
        result = self.run_check(rule, constraints)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        rule["conditions"][0] = oma("relation1", "neq", omv("a"), {"kind": "OMI", "integer": 0})
        self.assertEqual(self.run_check(rule, constraints).returncode, 1)

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


class StrengthenedConditionsTests(FaithfulnessTests):
    def test_added_condition_needs_a_finding(self):
        rule = self.good()
        rule["conditions"].append(oma("relation1", "neq", omv("b"), {"kind": "OMI", "integer": 0}))
        self.assertEqual(self.run_check(rule).returncode, 1)
        rule["findings"] = ["strengthened: the condition b ≠ 0 is added to the v0.1 conditions"]
        result = self.run_check(rule)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("1 strengthened", result.stdout)

    def test_strengthened_rule_keeps_the_original_conditions(self):
        rule = self.good()
        rule["conditions"] = rule["conditions"][1:] + [
            oma("relation1", "neq", omv("b"), {"kind": "OMI", "integer": 0})]
        rule["findings"] = ["strengthened: the condition b ≠ 0 is added to the v0.1 conditions"]
        self.assertEqual(self.run_check(rule).returncode, 1)


class ExpConventionTest(unittest.TestCase):
    def test_power_of_e_is_the_exponential(self):
        import v1_faithfulness as F
        got = F.convert(["Power", "E", ["Multiply", "c", "x"]],
                        {"Power": "openmath:arith1#power", "Multiply": "openmath:arith1#times"}, "x")
        self.assertEqual(got, {"kind": "OMA", "applicant": {"kind": "OMS", "cd": "transc1", "name": "exp"},
                               "arguments": [{"kind": "OMA",
                                              "applicant": {"kind": "OMS", "cd": "arith1", "name": "times"},
                                              "arguments": [{"kind": "OMV", "name": "c"},
                                                            {"kind": "OMV", "name": "x"}]}]})

    def test_bare_e_is_unchanged(self):
        import v1_faithfulness as F
        self.assertEqual(F.convert("E", {}, "x"), {"kind": "OMV", "name": "E"})
        got = F.convert(["Power", "a", "E"], {"Power": "openmath:arith1#power"}, "x")
        self.assertEqual(got["applicant"]["name"], "power")


class SimpConventionTest(unittest.TestCase):
    def test_simp_is_its_first_argument(self):
        import v1_faithfulness as F
        sem = {"Multiply": "openmath:arith1#times"}
        self.assertEqual(F.convert(["Simp", ["Multiply", "c", "x"], "x"], sem, "x"),
                         F.convert(["Multiply", "c", "x"], sem, "x"))
        self.assertEqual(F.convert(["Simp", ["Multiply", "c", "x"]], sem, "x"),
                         F.convert(["Multiply", "c", "x"], sem, "x"))


class CompoundConditionTest(unittest.TestCase):
    def test_and_and_negated_equalities_flatten(self):
        import v1_faithfulness as F
        got, ind = F.conditions([["And", ["FreeQ", ["List", "a"], "x"], ["Not", ["EqQ", "a", 0]]],
                                 ["Not", ["NeQ", "b", 1]]], {}, "x")
        want, _ = F.conditions([["NeQ", "a", 0], ["EqQ", "b", 1]], {}, "x")
        self.assertEqual((got, ind), (want, {"a"}))


class InertTrigConventionTest(unittest.TestCase):
    def test_inert_trig_is_the_trig_function(self):
        import v1_faithfulness as F
        sem = {"Sin": "openmath:transc1#sin", "Csc": "openmath:transc1#csc"}
        for low, up in (("sin", "Sin"), ("csc", "Csc")):
            self.assertEqual(F.convert([low, "a"], sem, "x"), F.convert([up, "a"], sem, "x"))


class AcothConventionTest(unittest.TestCase):
    def test_acoth_is_arctanh_of_the_reciprocal(self):
        import v1_faithfulness as F
        sem = {"Acoth": "openmath:transc1#arccoth", "Atanh": "openmath:transc1#arctanh",
               "Power": "openmath:arith1#power"}
        self.assertEqual(F.convert(["Acoth", "a"], sem, "x"),
                         F.convert(["Atanh", ["Power", "a", -1]], sem, "x"))


class AcotConventionTest(unittest.TestCase):
    def test_acot_is_arctan_of_the_reciprocal(self):
        import v1_faithfulness as F
        sem = {"Acot": "openmath:transc1#arccot", "Atan": "openmath:transc1#arctan",
               "Power": "openmath:arith1#power"}
        self.assertEqual(F.convert(["Acot", "a"], sem, "x"),
                         F.convert(["Atan", ["Power", "a", -1]], sem, "x"))


class SqrtConventionTest(unittest.TestCase):
    def test_sqrt_is_the_square_root(self):
        import v1_faithfulness as F
        got = F.convert(["Sqrt", "a"], {"Sqrt": "openmath:arith1#root"}, "x")
        self.assertEqual(got, {"kind": "OMA", "applicant": {"kind": "OMS", "cd": "arith1", "name": "root"},
                               "arguments": [{"kind": "OMV", "name": "a"}, {"kind": "OMI", "integer": 2}]})


if __name__ == "__main__":
    unittest.main()
