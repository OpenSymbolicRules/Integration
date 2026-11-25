"""Check the upstream integer-order primitives on the positive real interval."""
import json
import math
import unittest
from functools import lru_cache
from pathlib import Path


def quadrature(function, upper):
    # Composite Simpson integration on [0, upper].
    n = 2048
    h = upper / n
    interior = math.fsum((4 if i % 2 else 2) * function(i * h) for i in range(1, n))
    return (function(0) + interior + function(upper)) * h / 3


@lru_cache(maxsize=1024)
def cylinder(head, n, z):
    if n not in (0, 1, 2) or z <= 0:
        raise ValueError((n, z))
    pi = math.pi
    if head == "BesselJ":
        return quadrature(lambda t: math.cos(z * math.sin(t) - n * t), pi) / pi
    if head == "BesselY":
        circular = quadrature(lambda t: math.sin(z * math.sin(t) - n * t), pi)
        tail = quadrature(lambda t: (math.exp(n*t) + (-1)**n * math.exp(-n*t))
                          * math.exp(-z * math.sinh(t)), 8)
        return (circular - tail) / pi
    if head == "BesselI":
        return quadrature(lambda t: math.exp(z * math.cos(t)) * math.cos(n*t), pi) / pi
    if head == "BesselK":
        return quadrature(lambda t: math.exp(-z * math.cosh(t)) * math.cosh(n*t), 8)
    if head in ("HankelH1", "HankelH2"):
        y = cylinder("BesselY", n, z)
        return complex(cylinder("BesselJ", n, z), y if head == "HankelH1" else -y)
    raise ValueError(head)


def evaluate(node, x, a):
    if isinstance(node, int):
        return node
    if isinstance(node, str):
        return {"x": x, "a": a}[node]
    head, *args = node
    values = [evaluate(arg, x, a) for arg in args]
    if head == "Multiply":
        return math.prod(values)
    if head == "Add":
        return sum(values)
    if head == "Subtract":
        left, right = values
        return left - right
    if head == "Divide":
        left, right = values
        return left / right
    if head == "Power":
        base, exponent = values
        return base ** exponent
    return cylinder(head, *values)


class CylinderRegressions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.suite = json.loads(Path(__file__).with_name("examples.json").read_text())

    def test_source_and_scope(self):
        cases = self.suite["tests"]
        self.assertEqual(len(cases), 12)
        self.assertEqual(len({c["id"] for c in cases}), 12)
        self.assertEqual([c["source_lines"][0] for c in cases],
                         [10, 14, 18, 22, 26, 31, 36, 42, 53, 58, 64, 68])
        self.assertEqual(self.suite["constraints"],
                         [["FreeQ", "a", "x"], ["GtQ", "a", 0], ["GtQ", "x", 0]])
        for c in cases:
            self.assertEqual(c["variable"], "x")
            self.assertNotIn("num_steps", c)

    def test_oracle_normalization(self):
        for head, value in (("BesselJ", 0.7651976865579666), ("BesselY", 0.08825696421567696),
                            ("BesselI", 1.2660658777520084), ("BesselK", 0.4210244382407083)):
            self.assertAlmostEqual(cylinder(head, 0, 1), value, delta=1e-8)
        self.assertLess(cylinder("HankelH2", 0, 1).imag, 0)
        self.assertGreater(cylinder("HankelH1", 0, 1).imag, 0)
        with self.assertRaises(ValueError):
            cylinder("BesselK", 0, 0)
        with self.assertRaises(ValueError):
            cylinder("Undefined", 0, 1)

    def test_reference_derivatives(self):
        for case in self.suite["tests"]:
            for a in (0.75, 1.5):
                for x in (0.7, 1.3, 1.9):
                    with self.subTest(case=case["id"], x=x, a=a):
                        def primitive(t):
                            return evaluate(case["expected_result"], t, a)
                        h = 1e-4
                        derivative = (8 * (primitive(x+h) - primitive(x-h))
                                      - primitive(x+2*h) + primitive(x-2*h)) / (12*h)
                        self.assertLess(abs(derivative - evaluate(case["expression"], x, a)), 1e-7)


if __name__ == "__main__":
    unittest.main()
