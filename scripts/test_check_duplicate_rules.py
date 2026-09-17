#!/usr/bin/env python3
"""Regression tests for the exact duplicate-rule baseline checker."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("check_duplicate_rules.py")


class DuplicateRuleCheckerTests(unittest.TestCase):
    def write_rule(self, directory: Path, identity: str, rule_id: int = 1) -> None:
        document = {
            "identity": identity,
            "rules": [
                {
                    "id": rule_id,
                    "pattern": ["F", "x_"],
                    "constraints": [],
                    "result": ["G", "x_"],
                }
            ],
        }
        (directory / f"{identity}.json").write_text(
            json.dumps(document), encoding="utf-8"
        )

    def run_checker(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *arguments],
            text=True,
            capture_output=True,
            check=False,
        )

    def test_baseline_rejects_an_added_duplicate(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            rules = root / "rules"
            rules.mkdir()
            baseline = root / "baseline.json"
            self.write_rule(rules, "one")
            self.write_rule(rules, "two")

            self.assertEqual(
                self.run_checker(str(rules), "--baseline", str(baseline), "--write-baseline").returncode,
                0,
            )
            self.assertEqual(
                self.run_checker(str(rules), "--baseline", str(baseline)).returncode,
                0,
            )

            self.write_rule(rules, "three")
            result = self.run_checker(str(rules), "--baseline", str(baseline))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("membership changed", result.stderr)


if __name__ == "__main__":
    unittest.main()
