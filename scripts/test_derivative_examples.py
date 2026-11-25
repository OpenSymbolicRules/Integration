"""Differentiate the shipped 9.1 expressions numerically on real polynomial witnesses."""
import json
import math
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1] / "editions/rubi-4.17.3.0"


def check_instance(rule, cell, x, p, q, *, b=0.75):
    # Derivatives of t^5 and t^4. Negative orders take primitives vanishing at zero.
    negative = cell in (3, 6, 7)
    a = b if cell in (9, 10, 11) else 1.25
    if cell in (12, 13, 15):
        a = b * (p + 1)
    elif cell == 14:
        b = a * (q + 1)
    elif cell in (16, 17, 18):
        a = b * (p + 1) / (q + 1)
    n = -1 if negative else 2
    env = dict(a=a, b=b, c=1.25, F=2.0, m=3, m1=2, n=n, n1=n-1, p=p, q=q)
    constraints = rule["constraints"]
    inner = next((c[1] for c in constraints if c[0] == "FunctionOfQ"), None)

    def evaluate(term, t):
        if isinstance(term, (int, float)):
            return term
        if isinstance(term, str):
            name = term.rstrip("_.")
            if name == "x":
                return t
            if name == "u":
                return evaluate(inner, t) ** 2
            return env[name]
        head, *args = term
        if head == "Apply":
            fn, (_, arg) = args
            order = 0
            if isinstance(fn, list):
                _, (_, order_term), (_, fn) = fn
                order = evaluate(order_term, t)
            degree = {"f": 5, "g": 4}[fn.rstrip("_")]
            return (math.factorial(degree) / math.factorial(degree-order)
                    * evaluate(arg, t) ** (degree-order))
        if head == "Subst":
            # The test multiplier is exactly K(Z)=Z². Match the full held
            # substitution before using its primitive P(s)=s³/3.
            integral, variable, replacement = args
            expected = ["Int", ["SimplifyIntegrand", ["SubstFor", inner, "u", "x"], "x"], "x"]
            if variable != "x" or replacement != inner or integral != expected:
                raise AssertionError(f"Cell {cell}: inconsistent substitution")
            return evaluate(replacement, t) ** 3 / 3
        if head == "Int":
            residual, var = args
            if not negative or var != "x":
                raise AssertionError(f"Cell {cell}: unexpected residual integral")
            # Midpoint quadrature over one small interval, with R(x)=3.
            return 3 + (t-x) * evaluate(residual, (x+t)/2)
        values = [evaluate(v, t) for v in args]
        if head == "Add":
            return sum(values)
        if head in ("Star", "Multiply"):
            return math.prod(values)
        if head == "Power":
            return values[0] ** values[1]
        return {"Sin": math.sin, "Cos": math.cos, "Log": math.log}[head](*values)

    integrand = evaluate(rule["pattern"][1], x)
    if not math.isfinite(integrand):
        raise AssertionError(f"Cell {cell}: nonfinite witness integrand")
    h = 1e-5
    slope = (evaluate(rule["result"], x+h) - evaluate(rule["result"], x-h)) / (2*h)
    return math.isclose(slope, integrand, rel_tol=2e-7, abs_tol=2e-8)


class DerivativeExamples(unittest.TestCase):
    def test_all_fifteen_previously_missing_cells(self):
        ledger = json.loads((ROOT / "coverage.json").read_bytes())
        section, = (f for f in ledger["files"] if f["source_path"].startswith("9 Miscellaneous/9.1 "))
        active = json.loads((ROOT / "rules" / section["path"]).read_bytes())["rules"]
        rules = {r["id"]: r for r in active if r["id"] in (9, 12)}
        rules.update((o["ordinal"], o["source_rule"]) for o in section["omitted"])
        self.assertEqual(set(rules), {1, 3, *range(6, 19)})
        for cell, rule in rules.items():
            for x in (0.8, 1.125):
                with self.subTest(cell=cell, x=x):
                    self.assertTrue(check_instance(rule, cell, x, 0.5, -0.25))
            if cell in (3, 6, 7):
                with self.subTest(cell=cell, b=0):
                    free = ["a","b","c","f","F","p"] if cell == 3 else ["a","b","f"]
                    self.assertEqual(rule["constraints"], [["FreeQ",["List",*free],"x"],["ILtQ","n",0]])
                    with self.assertRaises(ZeroDivisionError):
                        check_instance(rule, cell, 1, 1, 0, b=0)
            if cell in (12, 13, 15):
                with self.subTest(cell=cell, p=-1):
                    self.assertTrue(check_instance(rule, cell, 1.125, -1, 0.5))


if __name__ == "__main__":
    unittest.main()
