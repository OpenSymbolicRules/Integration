"""The official paclet and the later maintenance checkout are separate inputs."""
import hashlib
import json
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

from audit_rubi_coverage import count_int_definitions
from check_duplicate_rules import canonical_payload
from rubi_release import RELEASE, ROOT, verify_archive


class ReleaseTest(unittest.TestCase):
    def test_refuses_a_different_archive_even_when_named_like_the_release(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / "Rubi-4.17.3.0.paclet"
            archive.write_bytes(b"not the release")
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                verify_archive(archive, {}, None)

    def test_release_inventory_and_erratum(self):
        edition = ROOT / "editions/rubi-4.17.3.0"
        self.assertIn("2018 Rule-Based-Integration Organization", (edition / "LICENSE").read_text())
        manifest = json.loads((edition / "rules/meta.json").read_text())
        ledger = json.loads((edition / "coverage.json").read_text())
        self.assertEqual(manifest["converter"]["source_commit"], RELEASE)
        self.assertEqual(ledger["revision"], RELEASE)
        files = ledger["files"]
        self.assertEqual([f["path"] for f in files], manifest["load_order"])
        self.assertEqual(len(set(manifest["load_order"])), 198)
        self.assertEqual(sum(f["converted"] for f in files), manifest["rule_count"])
        self.assertEqual(manifest["rule_count"], 7373)
        self.assertEqual(sum(len(f["omitted"]) for f in files), 21)
        issue, = json.loads((edition / "errata.json").read_text())
        doc = json.loads((edition / "rules" / issue["file"]).read_text())
        rule = next(r for r in doc["rules"] if r["id"] == issue["rule_id"])
        self.assertEqual((issue["source_revision"], issue["file_identity"], issue["source_cell"]),
                         (RELEASE, doc["identity"], 48))
        self.assertEqual(issue["action"], "skip")
        self.assertEqual(hashlib.sha256(canonical_payload(rule).encode()).hexdigest(), issue["payload_sha256"])

    def test_each_loaded_file_accounts_for_upstream_int_definitions(self):
        vendor = ROOT / "vendor/Rubi"
        if not (vendor / ".git").exists():
            self.skipTest("Rubi submodule is not initialized")
        for root in (ROOT / "rules", ROOT / "editions/rubi-4.17.3.0/rules"):
            manifest = json.loads((root / "meta.json").read_bytes())
            revision = manifest["converter"]["source_commit"]
            for path in manifest["load_order"]:
                doc = json.loads((root / path).read_bytes())
                source = doc["identity"].split(":", 1)[1]
                if root == ROOT / "rules":
                    source += ".m"
                blob = f"{revision}:Rubi/IntegrationRules/{source}"
                raw = subprocess.check_output(["git", "-C", vendor, "show", blob], text=True)
                # Each top-level step wrapper contains two Int definitions and loads one.
                wrappers = len(re.findall(r"(?m)^\s*If\[TrueQ\[\$LoadShowSteps\]", raw))
                omitted = 15 if source == "9 Miscellaneous/9.1 Derivative integration rules.m" else 0
                with self.subTest(revision=revision, source=source):
                    self.assertGreater(len(doc["rules"]), 0)
                    self.assertEqual(count_int_definitions(raw), len(doc["rules"]) + wrappers + omitted)

    def test_first_derivative_cells(self):
        edition = ROOT / "editions/rubi-4.17.3.0"
        path = "9-miscellaneous/9.1-Derivative-integration-rules.json"
        doc = json.loads((edition / "rules" / path).read_text())
        a, b, c = [r for r in doc["rules"] if r["id"] >= 19]
        self.assertEqual([r["id"] for r in (a, b, c)], [19, 20, 21])

        def call(head, arg):
            return ["Apply", head, ["List", arg]]

        def derivative(name):
            return call(call(["Derivative", 1], name), "x_")

        f, g = call("f_", "x_"), call("g_", "x_")
        left = ["Multiply", derivative("f_"), g]
        right = ["Multiply", f, derivative("g_")]
        numerator = ["Add", left, ["Multiply", -1, *right[1:]]]
        fx, gx = call("f", "x"), call("g", "x")
        ratio = ["Multiply", fx, ["Power", gx, -1]]
        self.assertEqual(a["pattern"], ["Int", ["Add", left, right], "x_symbol"])
        self.assertEqual(b["pattern"], ["Int", ["Multiply", numerator,
                         ["Power", ["Power", g, 2], -1]], "x_symbol"])
        self.assertEqual(c["pattern"], ["Int", ["Multiply", numerator,
                         ["Power", ["Multiply", f, g], -1]], "x_symbol"])
        self.assertEqual([r["result"] for r in (a, b, c)],
                         [["Multiply", fx, gx], ratio, ["Log", ratio]])
        for r in (a, b, c):
            self.assertEqual(r["constraints"], [["FreeQ", ["List", "f", "g"], "x"]])
        self.assertEqual(doc["semantics"]["Derivative"], "openmath:osr#Derivative")
        self.assertEqual(doc["semantics"]["Apply"], "openmath:osr#Apply")
        manifest = json.loads((edition / "rules/meta.json").read_text())
        extension, = [e for e in manifest["extensions"] if e["name"] == "Derivative"]
        self.assertEqual(extension["arity"], 1)
        self.assertIn("calculus1#diff", extension["semantics"])
        ledger = json.loads((edition / "coverage.json").read_text())
        section, = [s for s in ledger["files"] if s["path"] == path]
        self.assertEqual([o["ordinal"] for o in section["omitted"]], [1, 3, *range(6, 19)])

    def test_positive_order_residuals(self):
        edition = ROOT / "editions/rubi-4.17.3.0"
        path = "9-miscellaneous/9.1-Derivative-integration-rules.json"
        records = json.loads((edition / "rules" / path).read_text())["rules"]
        self.assertEqual([r["id"] for r in records], [2, 4, 5, 19, 20, 21])

        def derivative(order, f, x):
            return ["Apply", ["Apply", ["Derivative", order], ["List", f]], ["List", x]]

        previous = derivative(["Add", "n", ["Multiply", -1, 1]], "f", "x")
        affine = ["Add", "a", ["Multiply", "b", "x"]]
        exponential = ["Power", ["Multiply", "c", ["Power", "F", affine]], "p"]
        for r, weight, residual_weight in zip(records[:3], (exponential, ["Sin", affine], ["Cos", affine]),
                                             (exponential, ["Cos", affine], ["Sin", affine]), strict=True):
            self.assertEqual(r["pattern"][1][-1], derivative("n_", "f_", "x_"))
            free = ["a", "b", "c", "f", "F", "p"] if r["id"] == 2 else ["a", "b", "f"]
            self.assertEqual(r["constraints"], [["FreeQ", ["List", *free], "x"], ["IGtQ", "n", 0]])
            leading = ["Multiply", weight, previous]
            coefficient = ["Multiply", "b", "p", ["Log", "F"]] if r["id"] == 2 else "b"
            residual = ["Star", coefficient, ["Int", ["Multiply", residual_weight, previous], "x"]]
            correction = residual if r["id"] == 5 else ["Multiply", -1, residual]
            self.assertEqual(r["result"], ["Add", leading, correction])

    def test_release_has_an_immutable_git_revision(self):
        self.assertEqual(RELEASE, "f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4")


if __name__ == "__main__":
    unittest.main()
