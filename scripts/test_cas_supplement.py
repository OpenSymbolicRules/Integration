"""The four portable Airy rewrites and their one-step conformance examples."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1] / "supplements" / "airy"
REVISION = "3625e0e4bb1d78c0ce0acc038d75043aa48efdf1"


class AiryTest(unittest.TestCase):
    def test_equations_and_source_conditions(self):
        doc = json.loads((ROOT / "rules/airy.json").read_text())
        cases = json.loads((ROOT / "tests/airy.json").read_text())["tests"]
        expected = {}
        for i, name in enumerate(("Ai", "Bi"), 1):
            offset, slope = "a.", "b."
            arg = ["Add", offset, ["Multiply", slope, "x_"]]
            actual = next(r for r in doc["rules"] if r["id"] == i)
            self.assertEqual(actual["pattern"], ["Int", [name + "2", 1, arg], "x_symbol"])
            self.assertEqual(actual["constraints"], [["FreeQ", ["List", "a", "b"], "x"], ["NeQ", "b", 0]])
            self.assertEqual(actual["result"], ["Divide", [name, ["Add", "a", ["Multiply", "b", "x"]]], "b"])
            for a, b in ((2, 3), (1, -2)):
                z = ["Add", a, ["Multiply", b, "x"]]
                expected[repr([name + "2", 1, z])] = ["Divide", [name, z], b]
            moment = next(r for r in doc["rules"] if r["id"] == i + 2)
            self.assertEqual(moment["pattern"], ["Int", ["Multiply", "x_", [name, "x_"]], "x_symbol"])
            self.assertEqual(moment["constraints"], [])
            self.assertEqual(moment["result"], [name + "2", 1, "x"])
            expected[repr(["Multiply", "x", [name, "x"]])] = [name + "2", 1, "x"]
            for symbol in (name, name + "2"):
                self.assertEqual(doc["semantics"][symbol], "openmath:airy#" + symbol)
        self.assertEqual(len(cases), 6)
        self.assertEqual(expected, {repr(r["expression"]): r["expected_result"] for r in cases})
        self.assertTrue(all(r["num_steps"] == 1 and r["variable"] == "x" for r in cases))
        for rule in doc["rules"]:
            src = rule["provenance"]["sources"][0]
            self.assertEqual(src["revision"], REVISION)
            self.assertEqual(src["locator"].split("#")[-1], "8_2_" + str(rule["id"]))


if __name__ == "__main__":
    unittest.main()
