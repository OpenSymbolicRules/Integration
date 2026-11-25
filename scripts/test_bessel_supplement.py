"""Conformance of the positive-real moment rules against half-integer cylinder functions."""
import json
import math
import unittest
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "supplements/bessel"
CD_NAMES = {"BesselJ": "besselJ", "BesselY": "besselY", "HankelH1": "hankel1"}
REVISION = "3625e0e4bb1d78c0ce0acc038d75043aa48efdf1"


def cylinder(name, order, z):
    # Standard J_(±1/2) and Y_(±1/2), followed by the order recurrence.
    if z <= 0 or order < 0.5 or (order - 0.5) % 1:
        raise ValueError((order, z))
    factor = math.sqrt(2 / (math.pi * z))
    previous = factor * complex(math.cos(z), math.sin(z))
    value = factor * complex(math.sin(z), -math.cos(z))
    for i in range(int(order - 0.5)):
        previous, value = value, (2*i+1) * value / z - previous
    return {"BesselJ": value.real, "BesselY": value.imag, "HankelH1": value}[name]


def evaluate(term, env, integral=None):
    if isinstance(term, str):
        return env[term]
    if isinstance(term, int):
        return Fraction(term)
    head, *args = term
    if head == "Int":
        integrand, variable = args
        if variable != "x":
            raise ValueError(variable)
        return integral(integrand)
    values = [evaluate(arg, env, integral) for arg in args]
    if head in CD_NAMES:
        return cylinder(head, *values)
    arithmetic = {"Add": sum, "Multiply": math.prod,
                  "Subtract": lambda v: v[0] - v[1], "Divide": lambda v: v[0] / v[1],
                  "Power": lambda v: v[0] ** v[1]}
    return arithmetic[head](values)


def admits(rule, env):
    for head, *args in rule["constraints"]:
        if head == "FreeQ":
            symbols, var = args
            if symbols[0] != "List" or var != "x" or any(env[s] == var for s in symbols[1:]):
                return False
            continue
        vals = [evaluate(arg, env) for arg in args]
        if head == "EqQ":
            accepted = vals[0] == vals[1]
        elif head == "GtQ":
            accepted = vals[0] is not None and vals[0] > vals[1]
        elif head == "IGtQ":
            accepted = vals[0] % 1 == 0 and vals[0] > vals[1]
        elif head == "EvenQ":
            accepted = vals[0] % 2 == 0
        else:
            raise ValueError(head)
        if not accepted:
            return False
    return True


class BesselTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = json.loads((ROOT / "rules/bessel.json").read_text())
        cls.fixtures = json.loads((ROOT / "tests/moments.json").read_text())["tests"]

    def test_scope_and_provenance(self):
        rules = self.doc["rules"]
        self.assertEqual([r["id"] for r in rules], [1, 2, 5, 6, 9, 11])
        for rule in rules:
            name = rule["pattern"][1][2][0]
            self.assertEqual(rule["pattern"], ["Int", ["Multiply", ["Power", "x_", "m."],
                             [name, "nu_", ["Multiply", "a.", "x_"]]], "x_symbol"])
            self.assertEqual(self.doc["semantics"][name], "openmath:hypergeo2#" + CD_NAMES[name])
            src, = rule["provenance"]["sources"]
            self.assertEqual(src["revision"], REVISION)
            self.assertTrue(src["locator"].endswith("#8_1_" + str(rule["id"])))
            self.assertIn(["FreeQ", ["List", "m", "nu", "a"], "x"], rule["constraints"])
            direct = rule["id"] in (1, 2, 9)
            for m in (0, 1, 2, 3, 4, 5, Fraction(7, 2)):
                self.assertEqual(admits(rule, dict(nu=0, m=m, a=2, x=1)),
                                 m == 1 if direct else m in (3, 5))
            valid = dict(nu=0, m=1 if direct else 3, a=2, x=1)
            for key in ("x", "a"):
                for invalid in (0, -1, None):
                    self.assertFalse(admits(rule, {**valid, key: invalid}))
            for key in ("m", "nu", "a"):
                self.assertFalse(admits(rule, {**valid, key: "x"}))

    def test_primitive_and_step_count(self):
        def run(integrand, env, steps, last_gap=None):
            op, power, function = integrand
            self.assertEqual((op, power[:2]), ("Multiply", ["Power", "x"]))
            name, order, arg = function
            self.assertEqual((arg[0], arg[2]), ("Multiply", "x"))
            local = {**env, "nu": evaluate(order, env), "m": evaluate(power[2], env),
                     "a": evaluate(arg[1], env)}
            gap = local["m"] - local["nu"] - 1
            if last_gap is not None:
                self.assertEqual(gap, last_gap - 2)
            candidates = [r for r in self.doc["rules"] if r["pattern"][1][2][0] == name and admits(r, local)]
            rule, = candidates
            steps.append(rule["id"])
            return evaluate(rule["result"], local, lambda t: run(t, local, steps, gap))

        context = json.loads((ROOT / "test-context.json").read_text())
        self.assertEqual(context["test_file"], "tests/moments.json")
        self.assertEqual(context["constraints"], [["GtQ", "x", 0]])
        meta = json.loads((ROOT / "rules/meta.json").read_text())
        self.assertEqual((meta["rule_count"], meta["test_count"]), (6, 9))
        self.assertEqual(len({case["id"] for case in self.fixtures}), 9)
        self.assertEqual(len(self.fixtures), 9)
        self.assertEqual({(r["expression"][2][0], r["num_steps"]) for r in self.fixtures},
                         {(name, n) for name in CD_NAMES for n in (1, 2, 3)})
        for case in self.fixtures:
            for x in (0.5, 1.25, 2.0):
                with self.subTest(case=case["id"], x=x):
                    steps = []
                    env = {"x": x}
                    primitive = case["expected_result"]
                    answer = run(case["expression"], env, steps)
                    self.assertAlmostEqual(abs(answer - evaluate(primitive, env)), 0, delta=1e-9)
                    self.assertEqual(len(steps), case["num_steps"])
                    h = 0.0001
                    def value(t):
                        return evaluate(primitive, {"x": t})
                    derivative = (8*(value(x+h)-value(x-h)) - value(x+2*h) + value(x-2*h))/(12*h)
                    self.assertAlmostEqual(abs(derivative - evaluate(case["expression"], env)), 0, delta=1e-7)


if __name__ == "__main__":
    unittest.main()
