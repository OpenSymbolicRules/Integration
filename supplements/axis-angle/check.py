"""Exercise the serialized axis-angle rules against their numerical derivatives."""
import json
import math
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
ANGLE = ["Atan2", 0]


def value(t, env):
    if isinstance(t, str):
        return {"I": 1j, "Pi": math.pi, **env}[t]
    if isinstance(t, (int, float)):
        return t
    head, *args = t
    v = [value(i, env) for i in args]
    ops = {"Power": pow, "Add": lambda *items: sum(items), "Multiply": lambda *items: math.prod(items),
           "Divide": lambda a, b: a / b, "Abs": abs, "Im": lambda a: complex(a).imag,
           "Atan2": lambda horizontal, vertical: math.atan2(vertical, horizontal)}
    return ops[head](*v)


def admits(test, env):
    head, *args = test
    if head == "FreeQ":
        names, variable = args
        names = names[1:] if isinstance(names, list) else [names]
        return all(isinstance(env.get(n), (int, float, complex)) and n != variable for n in names)
    if head == "Or":
        return any(admits(c, env) for c in args)
    try:
        a, b = (value(t, env) for t in args)
        if head == "EqQ":
            return a == b
        if head == "NeQ":
            return a != b
        if head == "GtQ":
            return a > b
        if head == "LtQ":
            return a < b
    except (KeyError, TypeError):
        return False
    raise ValueError(head)


def slope(primitive, env):
    h = 0.0001
    def f(dx):
        return value(primitive, {**env, "x": env["x"] + dx})
    return (8*(f(h)-f(-h)) - f(2*h) + f(-2*h)) / (12*h)


class AxisAngle(unittest.TestCase):
    def setUp(self):
        self.doc = json.loads((HERE / "rules/angles.json").read_text())
        self.meta = json.loads((HERE / "rules/meta.json").read_text())
        self.tests = json.loads((HERE / "tests/angles.json").read_text())["tests"]
        self.context = json.loads((HERE / "test-context.json").read_text())

    def test_manifest(self):
        self.assertEqual(self.meta["license"], "MIT")
        self.assertEqual((self.meta["rule_count"], self.meta["test_count"]), (2, 2))
        self.assertEqual(self.meta["load_order"], ["angles.json"])
        self.assertEqual(self.context["test_file"], "tests/angles.json")
        self.assertEqual(self.doc["identity"], "osr-supplement:axis-angle")

    def test_rules_are_authored_from_their_lean_statements(self):
        for rule, theorem in zip(self.doc["rules"], ("affine", "quadratic"), strict=True):
            self.assertEqual(rule["references"]["Lean (real)"], "OSR.AxisAngle." + theorem)
            self.assertEqual(rule["provenance"]["method"], "authored")
            source, = rule["provenance"]["sources"]
            self.assertEqual(source["name"], "OpenSymbolicRules/Integration")
            self.assertEqual(source["license"], "MIT")
            self.assertEqual(source["locator"], "supplements/axis-angle/AxisAngle.lean#OSR.AxisAngle." + theorem)

    def test_rule_trees(self):
        affine, quadratic = self.doc["rules"]
        ord1 = ["Add", "b", ["Multiply", "a", "x"]]
        ord2 = ["Add", "b", ["Multiply", "a", ["Power", "x", 2]]]
        self.assertEqual(affine["pattern"],
                         ["Int", ANGLE + [["Add", "b.", ["Multiply", "a.", "x_"]]], "x_symbol"])
        self.assertEqual(quadratic["pattern"],
                         ["Int", ["Multiply", "x_", ANGLE + [["Add", "b.", ["Multiply", "a.", ["Power", "x_", 2]]]]],
                          "x_symbol"])
        for rule, ordinate, k in ((affine, ord1, 2), (quadratic, ord2, 4)):
            self.assertEqual(rule["result"], ["Divide", ["Multiply", "Pi", ["Abs", ordinate]], ["Multiply", k, "a"]])
            self.assertEqual(rule["constraints"], [
                ["FreeQ", ["List", "a", "b"], "x"], ["NeQ", "a", 0],
                ["EqQ", ["Im", "x"], 0], ["EqQ", ["Im", "a"], 0], ["EqQ", ["Im", "b"], 0],
                ["Or", ["GtQ", ordinate, 0], ["LtQ", ordinate, 0]],
            ])

    def test_derivatives_on_every_sign_interval(self):
        for rule in self.doc["rules"]:
            affine = rule["id"] == 1
            for a in (-2.5, -1, 0.5, 3):
                for b in (-4, -0.5, 0, 2):
                    for x in (-3.25, -1.5, -0.25, 0.75, 2.5):
                        env = {"a": a, "b": b, "x": x}
                        ordinate = b + a * (x if affine else x * x)
                        if abs(ordinate) < 1e-3:
                            continue
                        with self.subTest(rule=rule["id"], env=env):
                            self.assertTrue(all(admits(c, env) for c in rule["constraints"]))
                            integrand = (1 if affine else x) * math.copysign(math.pi / 2, ordinate)
                            self.assertAlmostEqual(slope(rule["result"], env), integrand, delta=1e-7)

    def test_guards_reject_degenerate_and_complex_inputs(self):
        for rule in self.doc["rules"]:
            for env in ({"a": 0, "b": 1, "x": 1}, {"a": 1, "b": -1, "x": 1}, {"a": 1j, "b": 0, "x": 1},
                        {"a": 1, "b": 1j, "x": 1}, {"a": 1, "b": 0, "x": 1j}, {"a": 1, "b": "x", "x": 2}):
                with self.subTest(rule=rule["id"], env=env):
                    self.assertFalse(all(admits(c, env) for c in rule["constraints"]))

    def test_fixtures(self):
        self.assertEqual([t["id"] for t in self.tests], [1, 2])
        for test in self.tests:
            self.assertEqual(test["num_steps"], 1)
            for x in (-2.5, -0.75, 1.25, 3.5):
                env = {"x": x}
                with self.subTest(test=test["id"], x=x):
                    self.assertTrue(all(admits(c, env) for c in self.context["constraints"]))
                    self.assertAlmostEqual(slope(test["expected_result"], env), value(test["expression"], env),
                                           delta=1e-7)

    def test_no_third_party_text(self):
        for path in HERE.rglob("*"):
            if path.is_file() and path.name != "check.py":
                text = path.read_text(encoding="utf-8").lower()
                for word in ("maxima", "gpl", "general public license", "copying"):
                    self.assertNotIn(word, text, f"{path.name}: {word}")


if __name__ == "__main__":
    unittest.main()
