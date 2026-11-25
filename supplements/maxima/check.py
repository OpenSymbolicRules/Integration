"""Exercise the serialized Maxima rules and branch-sensitive reference primitives."""
import cmath
import json
import math
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REV = "1b81426deabf5f8366ce07aafc581944673a5467"


def value(t, env):
    if isinstance(t, str):
        return {"I": 1j, "Pi": math.pi, **env}[t]
    if isinstance(t, int):
        return t
    head, *args = t
    v = [value(i, env) for i in args]
    ops = {"Power": pow, "Add": lambda *items: sum(items), "Multiply": lambda *items: math.prod(items),
           "Divide": lambda a,b: a/b, "Subtract": lambda a,b: a-b, "Negate": lambda a: -a,
           "Abs": abs, "Log": cmath.log, "Sqrt": cmath.sqrt, "Im": lambda a: complex(a).imag,
           "Atan2": lambda horizontal, vertical: math.atan2(vertical, horizontal)}
    return ops[head](*v)


def admits(test, env):
    head, *args = test
    if head == "FreeQ":
        parameter, variable = args
        return isinstance(env.get(parameter), (int, float, complex)) and parameter != variable
    if head == "Or":
        return any(admits(c, env) for c in args)
    try:
        a, b = (value(t, env) for t in args)
        if head == "EqQ":
            return a == b
        if head == "GtQ":
            return a > b
        if head == "LtQ":
            return a < b
    except (KeyError, TypeError):
        return False
    raise ValueError(head)


def differentiated(primitive, env):
    h = 0.0001
    def f(dx):
        return value(primitive, {**env, "x": env["x"] + dx})
    return (8*(f(h)-f(-h)) - f(2*h) + f(-2*h)) / (12*h)


class MaximaBranches(unittest.TestCase):
    def test_angles(self):
        doc = json.loads((HERE / "rules/angles.json").read_text())
        fixtures = json.loads((HERE / "tests/angles.json").read_text())["tests"]
        context = json.loads((HERE / "test-context.json").read_text())
        self.assertEqual(context["test_file"], "tests/angles.json")
        meta = json.loads((HERE / "rules/meta.json").read_text())
        self.assertEqual((meta["rule_count"], meta["test_count"]), (2, 2))
        self.assertEqual(doc["semantics"]["Atan2"], "openmath:transc2#arctan")
        self.assertEqual([r["id"] for r in doc["rules"]], [1, 2])
        self.assertEqual([c["id"] for c in fixtures], [1, 2])
        for fixture, rule in zip(fixtures, doc["rules"], strict=True):
            linear = rule["id"] == 1
            xpart = "x_" if linear else ["Power", "x_", 2]
            angle = ["Atan2", 0, ["Add", "b.", xpart]]
            integrand = angle if linear else ["Multiply", "x_", angle]
            self.assertEqual(rule["pattern"], ["Int", integrand, "x_symbol"])
            self.assertEqual(rule["provenance"]["sources"][0]["revision"], REV)
            self.assertEqual(fixture["num_steps"], 1)
            src = ["Atan2", 0, "x"] if linear else ["Multiply", "x", ["Atan2", 0, ["Add", -1, ["Power", "x", 2]]]]
            self.assertEqual(fixture["expression"], src)
            shift = 0 if linear else -1
            for x in (-2.5, -0.5, 0.5, 2.5):
                env = {"x": x, "b": shift}
                self.assertTrue(all(admits(g, env) for g in context["constraints"]))
                self.assertTrue(all(admits(g, env) for g in rule["constraints"]))
                self.assertAlmostEqual(value(rule["result"], env), value(fixture["expected_result"], env))
                self.assertAlmostEqual(differentiated(rule["result"], env), value(src, env), delta=1e-8)
            for b in (-3, 2):
                for x in (-2.25, -0.75, 0.5, 2.25):
                    env = {"x": x, "b": b}
                    self.assertTrue(all(admits(g, env) for g in rule["constraints"]))
                    ordinate = b + (x if linear else x*x)
                    expected = (1 if linear else x) * math.copysign(math.pi/2, ordinate)
                    self.assertAlmostEqual(differentiated(rule["result"], env), expected, delta=1e-8)
            for env in ({"x": 0, "b": 0}, {"x": 1, "b": -1}, {"x": 1j, "b": 0},
                        {"x": 1, "b": 1j}, {"x": 1, "b": "x"}, {"b": shift}):
                self.assertFalse(all(admits(g, env) for g in rule["constraints"]))

    def test_logarithms(self):
        suite = json.loads((HERE.parent / "maxima-regressions/examples.json").read_text())
        self.assertEqual(suite["revision"], "8806ad76963d385137fc8b5198746f98565b3f61")
        # All connected components of the selected real domains are sampled.
        samples = {
            "imaginary-shift": [({}, x) for x in (-2, 0, 2)],
            "real-reciprocal": [({}, x) for x in (-2, 2)],
            "nested-root": [({"a": a}, x) for a in (-1, -4) for x in (-2, 2)],
            "real-split-poles": [({"a": a}, x) for a in (-1, 1) for x in (-2, 0, 2)],
        }
        excluded = {"imaginary-shift": [], "real-reciprocal": [{"x": 0}],
                    "nested-root": [{"a": 0, "x": 1}, {"a": 1, "x": 2}, {"a": -1, "x": 0}],
                    "real-split-poles": [{"a": 0, "x": 1}, {"a": 1, "x": -1}, {"a": 1, "x": 1}]}
        self.assertCountEqual([c["id"] for c in suite["tests"]], list(samples))
        for case in suite["tests"]:
            self.assertEqual(case["variable"], "x")
            self.assertNotIn("num_steps", case)
            for params, x in samples[case["id"]]:
                env = {**params, "x": x}
                with self.subTest(id=case["id"], env=env):
                    self.assertTrue(all(admits(c, env) for c in case["constraints"]))
                    self.assertAlmostEqual(abs(differentiated(case["expected_result"], env)
                                               - value(case["expression"], env)), 0, delta=1e-8)
            for env in excluded[case["id"]] + [{"x": 1j, "a": -1}]:
                self.assertFalse(all(admits(c, env) for c in case["constraints"]))


if __name__ == "__main__":
    unittest.main()
