"""Regression witness for RUBI 4.5.2.1 #47 as serialized in the source profile."""
import json
import math
import unittest
from pathlib import Path


class CosecantWitness(unittest.TestCase):
    def test_residual_integrand_at_pi_over_two(self):
        root = Path(__file__).resolve().parents[1] / "rules"
        doc = json.loads(next(root.rglob("4.5.2.1-*.json")).read_text())
        rule = next(r for r in doc["rules"] if r["id"] == 47)
        env = dict(a=1, b=1, c=1, d=1, e=0, f=1, m=1, n=0.5, p=2, x=math.pi/2)
        self.assertEqual(rule["constraints"], [
            ["FreeQ", ["List", "a", "b", "c", "d", "e", "f", "m", "n", "p"], "x"],
            ["Not", ["IntegerQ", "n"]]])
        self.assertFalse(env["n"].is_integer())

        def value(expr):
            if isinstance(expr, str):
                return env[expr.rstrip("._")]
            if not isinstance(expr, list):
                return expr
            head, *args = expr
            ops = {"Add": lambda *xs: sum(xs), "Multiply": lambda *xs: math.prod(xs),
                   "Power": pow, "Csc": lambda x: 1/math.sin(x), "csc": lambda x: 1/math.sin(x),
                   "Cos": math.cos, "IntPart": math.trunc, "FracPart": lambda n: n-math.trunc(n)}
            return ops[head](*map(value, args))

        head, *factors, residual = rule["result"]
        self.assertEqual((rule["pattern"][0], head, residual[0], residual[2]),
                         ("Int", "Multiply", "Int", "x"))
        self.assertAlmostEqual(value(rule["pattern"][1]), 2)
        self.assertAlmostEqual(math.prod(map(value, factors)), 1)
        self.assertAlmostEqual(value(residual[1]), 0)


if __name__ == "__main__":
    unittest.main()
