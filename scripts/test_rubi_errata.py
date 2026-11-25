"""Regression witness for RUBI 4.5.2.1 #47 as serialized in the source profile."""
import hashlib
import json
import math
import unittest
from pathlib import Path

from check_duplicate_rules import canonical_payload


class CosecantWitness(unittest.TestCase):
    def test_residual_integrand_at_pi_over_two(self):
        root = Path(__file__).resolve().parents[1]
        records = json.loads((root / "docs/rubi-errata.json").read_text())
        item = next(r for r in records if r["section"] == "4.5.2.1" and r["rule_id"] == 47)
        manifest = json.loads((root / "rules/meta.json").read_text())
        self.assertIn(item["file"], manifest["load_order"])
        self.assertEqual(item["source_revision"], manifest["converter"]["source_commit"])
        doc = json.loads((root / "rules" / item["file"]).read_text())
        self.assertEqual(doc["identity"], item["file_identity"])
        rule = next(r for r in doc["rules"] if r["id"] == item["rule_id"])
        self.assertEqual(item["payload_sha256"], hashlib.sha256(canonical_payload(rule).encode()).hexdigest())
        self.assertEqual(item["action"], "skip")
        self.assertEqual(item["lean_declaration"], "OSRTest.RubiCosecant.wrong_residual")
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
