"""Differentiate portable reference primitives numerically at real sample points."""
import json
import math
from pathlib import Path
import unittest

SUPPLEMENTS = Path(__file__).resolve().parents[1] / "supplements"


def airy(name, order, x):
    # Taylor coefficients of y'' = x y, with standard Ai and Bi initial values.
    y0 = 1 / (3 ** (2/3) * math.gamma(2/3))
    y1 = -1 / (3 ** (1/3) * math.gamma(1/3))
    if name == "Bi":
        y0 *= math.sqrt(3)
        y1 *= -math.sqrt(3)
    coeff = [y0, y1, 0]
    for n in range(3, 69):
        coeff.append(coeff[n-3] / (n * (n-1)))
    if order == 1:
        coeff = [i * c for i, c in enumerate(coeff)][1:]
    return math.fsum(c * x**i for i, c in enumerate(coeff))


def fresnel(trig, x):
    # Composite Simpson quadrature for the standard pi*t^2/2 normalization.
    intervals = 128
    step = x / intervals
    terms = []
    for i in range(intervals + 1):
        weight = 1 if i in (0, intervals) else 4 if i % 2 else 2
        terms.append(weight * trig(math.pi * (i * step)**2 / 2))
    return step * math.fsum(terms) / 3


def evaluate(expr, x):
    if isinstance(expr, (int, float)):
        return expr
    if isinstance(expr, str):
        return {"x": x, "Pi": math.pi}[expr]
    head, *args = expr
    values = [evaluate(arg, x) for arg in args]
    if head in ("Ai", "Bi"):
        return airy(head, 0, *values)
    if head in ("Ai2", "Bi2"):
        order, z = values
        if order != 1:
            raise ValueError(f"unsupported Airy derivative order {order}")
        return airy(head[:-1], order, z)
    unary = {"Sin": math.sin, "Cos": math.cos, "Sqrt": math.sqrt, "Abs": abs,
             "FresnelC": lambda z: fresnel(math.cos, z), "FresnelS": lambda z: fresnel(math.sin, z)}
    if head in unary:
        return unary[head](*values)
    ops = {"Add": lambda *xs: sum(xs), "Multiply": lambda *xs: math.prod(xs),
           "Divide": lambda a, b: a / b, "Power": pow}
    return ops[head](*values)


class ReferencesTest(unittest.TestCase):
    def check_examples(self, cases, expected_count=6, samples=(-0.75, 0.0, 0.625)):
        self.assertEqual(len(cases), expected_count)
        self.assertEqual(len({case["id"] for case in cases}), expected_count)
        for case in cases:
            for x in samples:
                with self.subTest(case=case["id"], x=x):
                    h = 0.0001
                    def primitive(t):
                        return evaluate(case["expected_result"], t)
                    slope = (8*(primitive(x+h) - primitive(x-h))
                             - primitive(x+2*h) + primitive(x-2*h)) / (12*h)
                    self.assertAlmostEqual(slope, evaluate(case["expression"], x), delta=1e-6)

    def test_airy(self):
        cases = json.loads((SUPPLEMENTS / "airy/tests/airy.json").read_text())["tests"]
        self.check_examples(cases)

    def test_sympy(self):
        data = json.loads((SUPPLEMENTS / "sympy-regressions/examples.json").read_text())
        self.assertEqual(data["revision"], "6856a0953eb7269e094a7755a8151d684bcb879c")
        self.assertTrue(all(case["variable"] == "x" and "num_steps" not in case for case in data["tests"]))
        x = "x"
        square = ["Power", x, 2]
        expected = {}
        for first in ("Sin", "Cos"):
            for second in ("Sin", "Cos"):
                expected[first.lower() + "2-" + second.lower()] = ["Multiply", [first, square], [second, x]]
            expected["x-" + first.lower()] = ["Multiply", x, [first, ["Add", square, x]]]
        self.assertEqual({case["id"]: case["expression"] for case in data["tests"]}, expected)
        self.check_examples(data["tests"])


if __name__ == "__main__":
    unittest.main()
