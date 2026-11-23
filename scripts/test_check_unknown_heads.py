"""Prevent legacy fabricated heads from entering the default rule sequence."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("check_unknown_heads.py")


class UnknownHeadTests(unittest.TestCase):
    def run_check(self, root):
        return subprocess.run([sys.executable, str(SCRIPT), str(root)],
                              text=True, capture_output=True)

    def test_loaded_and_excluded_rule_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "meta.json").write_text(json.dumps({"load_order": ["safe.json"]}))
            (root / "safe.json").write_text(json.dumps({"rules": [{"id": 1, "result": ["Add", 1, 2]}]}))
            (root / "excluded.json").write_text(json.dumps({"rules": [{"id": 2, "result": ["UnknownHead", "x"]}]}))
            result = self.run_check(root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("excluded", result.stdout)
            (root / "safe.json").write_text(json.dumps({"rules": [{"id": 1, "result": ["Add", ["UnknownHead", "x"], 2]}]}))
            result = self.run_check(root)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("safe.json", result.stderr)

    def test_invalid_manifest_path_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "meta.json").write_text(json.dumps({"load_order": ["missing.json"]}))
            self.assertNotEqual(self.run_check(root).returncode, 0)


if __name__ == "__main__":
    unittest.main()
