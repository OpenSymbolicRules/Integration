"""Regression witnesses for the RUBI errata in docs/rubi-errata.json.

Records either replace a shipped rule or enable an omitted source rule with
added guards.

Each record names a shipped rule by file identity, local ID and payload digest
and gives its replacement. These tests check that the records still match the
shipped rules, and evaluate the original and the corrected rules at explicit
points: the original disagrees with its integrand, the replacement agrees."""
import hashlib
import json
import math
import unittest
from pathlib import Path

from check_duplicate_rules import canonical_payload

ROOT = Path(__file__).resolve().parents[1]
COMPAT = "61e9c18ea248061cd83c67882f7c91a73cef912d"
RELEASE = "f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4"


def records():
    return json.loads((ROOT / "docs/rubi-errata.json").read_text())


def digest(rule):
    return hashlib.sha256(canonical_payload(rule).encode()).hexdigest()


def shipped(item):
    base = ROOT / ("rules" if item["source_revision"] == COMPAT else "editions/rubi-4.17.3.0/rules")
    doc = json.loads((base / item["file"]).read_text())
    return doc, next(r for r in doc["rules"] if r["id"] == item["rule_id"])


def evaluate(expr, env, funcs):
    """Numeric value of an OSR expression; pattern names lose their `_`/`.` suffix."""
    if isinstance(expr, str):
        return env[expr.rstrip("._")]
    if not isinstance(expr, list):
        return expr
    head, *args = expr
    ops = {"Add": lambda *xs: sum(xs), "Multiply": lambda *xs: math.prod(xs),
           "Star": lambda *xs: math.prod(xs), "Power": pow, "Log": math.log,
           "Csc": lambda x: 1 / math.sin(x), "csc": lambda x: 1 / math.sin(x), "Cos": math.cos,
           "IntPart": math.trunc, "FracPart": lambda n: n - math.trunc(n)}
    name = head.rstrip("._")
    fn = funcs.get(name) or ops[name]
    return fn(*(evaluate(a, env, funcs) for a in args))


def derivative(f, x, h=1e-6):
    return (f(x + h) - f(x - h)) / (2 * h)


def replacements():
    return [r for r in records() if r["action"] == "replace"]


class ErrataRecords(unittest.TestCase):
    def test_records_match_the_shipped_rules(self):
        manifest = json.loads((ROOT / "rules/meta.json").read_text())
        self.assertEqual(COMPAT, manifest["converter"]["source_commit"])
        self.assertEqual({r["action"] for r in records()}, {"replace", "enable"})
        seen = set()
        for item in replacements():
            with self.subTest(item=(item["file_identity"], item["rule_id"])):
                doc, rule = shipped(item)
                self.assertEqual(doc["identity"], item["file_identity"])
                self.assertEqual(item["payload_sha256"], digest(rule))
                self.assertEqual(item["action"], "replace")
                self.assertEqual(item["replacement_sha256"], digest(item["replacement"]))
                self.assertNotEqual(item["payload_sha256"], item["replacement_sha256"])
                self.assertEqual(rule["pattern"], item["replacement"]["pattern"])
                self.assertTrue(item["issue"].startswith("https://github.com/OpenSymbolicRules/Integration/issues/"))
                if item["source_revision"] == COMPAT:
                    self.assertIn(item["file"], manifest["load_order"])
                    self.assertIsInstance(item["source_line"], int)
                else:
                    self.assertEqual(item["source_revision"], RELEASE)
                    self.assertIsInstance(item["source_cell"], int)
                seen.add((item["section"], item["source_revision"]))
        # Seven corrected rules, each in both lineages.
        self.assertEqual(len(replacements()), 14)
        self.assertEqual(len(seen), 12)


class EnabledDerivativeRules(unittest.TestCase):
    """9.1 cells 1 and 8 (issue #13): omitted source rules enabled with IGtQ[n, 0]."""

    def test_enabled_rules(self):
        from test_derivative_examples import check_instance
        ledger = json.loads((ROOT / "editions/rubi-4.17.3.0/coverage.json").read_text())
        section, = (f for f in ledger["files"] if f["source_path"].startswith("9 Miscellaneous/9.1 "))
        omitted = {o["ordinal"]: o for o in section["omitted"]}
        items = [r for r in records() if r["action"] == "enable"]
        self.assertEqual(sorted((r["source_revision"], r["source_cell"]) for r in items),
                         sorted((rev, c) for rev in (COMPAT, RELEASE) for c in (1, 8)))
        for item in items:
            with self.subTest(item=(item["source_revision"], item["source_cell"])):
                base = ROOT / ("rules" if item["source_revision"] == COMPAT else "editions/rubi-4.17.3.0/rules")
                doc = json.loads((base / item["file"]).read_text())
                self.assertEqual(doc["identity"], item["file_identity"])
                ids = [r["id"] for r in doc["rules"]]
                self.assertNotIn(item["rule_id"], ids)
                following = next(r for r in doc["rules"] if r["id"] == item["insert_before"])
                self.assertTrue(following["provenance"]["sources"][0]["locator"].endswith(
                    f"#{item['source_cell'] + 1}"))
                source = omitted[item["source_cell"]]
                # The source rule with the guards proposed by the ledger appended.
                self.assertEqual(item["added_constraints"], source["order_and_divisor_guards"])
                expected = {k: source["source_rule"][k] for k in ("pattern", "result")}
                expected["constraints"] = source["source_rule"]["constraints"] + item["added_constraints"]
                self.assertEqual(item["rule"], expected)
                self.assertEqual(item["rule_sha256"], digest(item["rule"]))
                self.assertEqual(item["proof"], source["real_interpretation"]["source"])
                self.assertEqual(item["lean_declaration"], source["real_interpretation"]["theorem"])
                # Differentiate the result at polynomial witnesses (order 2).
                for x in (0.8, 1.125):
                    self.assertTrue(check_instance(item["rule"], item["source_cell"], x, 0.5, -0.25))


class CosecantWitness(unittest.TestCase):
    """RUBI 4.5.2.1 #47 (release cell 48): Cos for Csc in the residual integral."""

    env = dict(a=1, b=1, c=1, d=1, e=0, f=1, m=1, n=0.5, p=2, x=math.pi / 2)

    def test_residual_integrand_at_pi_over_two(self):
        for item in replacements():
            if item["section"] != "4.5.2.1":
                continue
            with self.subTest(revision=item["source_revision"]):
                _, rule = shipped(item)
                self.assertEqual(item["lean_declaration"], "OSRTest.RubiCosecant.wrong_residual")
                self.assertEqual(rule["constraints"][0],
                                 ["FreeQ", ["List", "a", "b", "c", "d", "e", "f", "m", "n", "p"], "x"])
                self.assertFalse(self.env["n"].is_integer())
                for payload, residual_value in ((rule, 0), (item["replacement"], 2)):
                    head, *factors, residual = payload["result"]
                    self.assertEqual((payload["pattern"][0], residual[0], residual[2]), ("Int", "Int", "x"))
                    # The input integrand is 2 and the extracted factor is identically 1 near π/2,
                    # so the residual integrand must be 2 there; the source's cosine gives 0.
                    self.assertAlmostEqual(evaluate(payload["pattern"][1], self.env, {}), 2)
                    factor = lambda x: math.prod(evaluate(f, {**self.env, "x": x}, {}) for f in factors)
                    self.assertAlmostEqual(factor(self.env["x"]), 1)
                    self.assertAlmostEqual(derivative(factor, self.env["x"]), 0, places=6)
                    self.assertAlmostEqual(evaluate(residual[1], self.env, {}), residual_value)


class LogarithmicSubstitutionWitness(unittest.TestCase):
    """8.1 #52, 8.2 #53, 8.4 #27 and 8.5 #27: Int[F[d (a + b Log[c x^n])]/x, x].

    The identity does not depend on F; F = erf is used as a differentiable stand-in.
    The witness is the one of issue #12: a = 0, b = c = d = n = 1 at x = 1."""

    env = dict(a=0.0, b=1.0, c=1.0, d=1.0, n=1.0)
    funcs = {"F": math.erf}

    def test_original_and_replacement(self):
        items = [r for r in replacements() if r["section"] in ("8.1", "8.2", "8.4", "8.5")
                 and r["replacement"]["result"][-1][0] == "Subst"
                 and r["replacement"]["result"][-1][1][0] == "Int"
                 and "Log" in json.dumps(r["replacement"]["result"][-1][3])]
        self.assertEqual(len(items), 8)
        for item in items:
            with self.subTest(item=(item["section"], item["source_revision"])):
                _, rule = shipped(item)
                env = dict(self.env)
                integrand = lambda x: evaluate(rule["pattern"][1], {**env, "x": x}, self.funcs)
                # Source: the coefficient times F evaluated at the substituted argument.
                *factors, subst = rule["result"][1:]
                self.assertEqual(subst[0], "Subst")
                coef = math.prod(evaluate(f, env, {}) for f in factors)
                original = lambda x: coef * evaluate(subst[1], {**env, "x": evaluate(subst[3], {**env, "x": x}, {})}, self.funcs)
                self.assertAlmostEqual(integrand(1.0), 0.0)
                self.assertAlmostEqual(derivative(original, 1.0), 2 / math.sqrt(math.pi), places=6)
                # Replacement: the derivative of coef * Φ(L(x)) with Φ' = body is coef * body(L) L'.
                *factors, subst = item["replacement"]["result"][1:]
                self.assertEqual((subst[0], subst[1][0], subst[1][2], subst[2]), ("Subst", "Int", "x", "x"))
                coef = math.prod(evaluate(f, env, {}) for f in factors)
                body, target = subst[1][1], subst[3]
                for x in (0.4, 1.0, 2.7):
                    L = lambda y: evaluate(target, {**env, "x": y}, {})
                    value = coef * evaluate(body, {**env, "x": L(x)}, self.funcs) * derivative(L, x)
                    self.assertAlmostEqual(value, integrand(x), places=6)

    def test_member_condition_names_the_function(self):
        for item in replacements():
            if item["section"] in ("8.4", "8.5"):
                with self.subTest(item=(item["section"], item["source_revision"])):
                    _, rule = shipped(item)
                    self.assertIn(["MemberQ", rule["constraints"][-1][1], "x"], rule["constraints"])
                    self.assertIn(["MemberQ", rule["constraints"][-1][1], "F"],
                                  item["replacement"]["constraints"])


class ProportionalSubstitutionWitness(unittest.TestCase):
    """8.1 #69 and 3.3 #33: u = d + e x maps g + h x to g u/d only when e g = d h."""

    funcs = {"F": math.erf}

    def check(self, item, env, holds):
        payload = item["replacement"]
        integrand = lambda x: evaluate(payload["pattern"][1], {**env, "x": x}, self.funcs)
        *factors, subst = payload["result"][1:]
        coef = math.prod(evaluate(f, env, {}) for f in factors)
        body, target = subst[1][1], subst[3]
        for x in (0.3, 1.1):
            U = lambda y: evaluate(target, {**env, "x": y}, {})
            value = coef * evaluate(body, {**env, "x": U(x)}, self.funcs) * derivative(U, x)
            if holds:
                self.assertAlmostEqual(value, integrand(x), places=6)
            else:
                self.assertGreater(abs(value - integrand(x)), 1e-3)

    def test_condition(self):
        items = [r for r in replacements() if r["section"] in ("3.3",) or (r["section"] == "8.1" and
                 r["replacement"]["result"][-1][3] == ["Add", "d", ["Multiply", "e", "x"]])]
        self.assertEqual(len(items), 4)
        for item in items:
            with self.subTest(item=(item["section"], item["source_revision"])):
                _, rule = shipped(item)
                wrong = ["EqQ", ["Add", ["Multiply", "e", "f"], ["Multiply", -1, "d", "g"]], 0]
                right = ["EqQ", ["Add", ["Multiply", "e", "g"], ["Multiply", -1, "d", "h"]], 0]
                self.assertIn(wrong, rule["constraints"])
                self.assertIn(right, item["replacement"]["constraints"])
                self.assertNotIn(wrong, item["replacement"]["constraints"])
                self.assertIn("h", next(k for k in item["replacement"]["constraints"] if k[0] == "FreeQ")[1])
                self.assertEqual(rule["result"], item["replacement"]["result"])
                base = dict(a=0.5, b=0.7, c=1.3, d=2.0, e=3.0, m=2.0, n=1.0, p=2.0)
                # The source condition e f = d g holds, the corrected one fails: the rule is false.
                self.check(item, {**base, "f": 2.0, "g": 3.0, "h": 1.0}, holds=False)
                # The corrected condition e g = d h holds: the rewrite is an identity.
                self.check(item, {**base, "f": 0.9, "g": 2.0, "h": 3.0}, holds=True)


if __name__ == "__main__":
    unittest.main()
