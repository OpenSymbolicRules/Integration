"""The official paclet and the later maintenance checkout are separate inputs."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

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
        self.assertEqual(manifest["rule_count"], 7252)
        self.assertEqual(sum(len(f["omitted"]) for f in files), 142)
        issue, = json.loads((edition / "errata.json").read_text())
        doc = json.loads((edition / "rules" / issue["file"]).read_text())
        rule = next(r for r in doc["rules"] if r["id"] == issue["rule_id"])
        self.assertEqual((issue["source_revision"], issue["file_identity"], issue["source_cell"]),
                         (RELEASE, doc["identity"], 48))
        self.assertEqual(issue["action"], "skip")
        self.assertEqual(hashlib.sha256(canonical_payload(rule).encode()).hexdigest(), issue["payload_sha256"])

    def test_first_derivative_cells(self):
        edition = ROOT / "editions/rubi-4.17.3.0"
        path = "9-miscellaneous/9.1-Derivative-integration-rules.json"
        doc = json.loads((edition / "rules" / path).read_text())
        a, b, c = doc["rules"]
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
        self.assertEqual([o["ordinal"] for o in section["omitted"]], list(range(1, 19)))

    def test_release_has_an_immutable_git_revision(self):
        self.assertEqual(RELEASE, "f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4")


if __name__ == "__main__":
    unittest.main()
