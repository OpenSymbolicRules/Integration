"""Verify each pinned RUBI show-steps definition against its distributed plain branch."""
import argparse
import json
import re
import subprocess
from pathlib import Path

from check_duplicate_rules import canonical_payload

# Pinned source ordinal -> stable OSR ID. The array order controls precedence.
EXPECTED = {
    "1.4.1": {9: 71}, "3.5": {46: 44}, "4.1.0.1": {4: 25},
    "4.7.5": {24: 33, 25: 34, 50: 57, 51: 58, 61: 65, 74: 72},
    "5.3.7": {30: 74, 31: 75}, "7.3.7": {28: 69, 29: 70},
    "9.3": {38: 34, 39: 35, 52: 48, 53: 49, 54: 50, 56: 52, 57: 53, 58: 54, 67: 62},
}


def check(vendor, edition, rules):
    ledger = json.loads((edition / "coverage.json").read_text())
    observed = {}
    for file in ledger["files"]:
        blob = ledger["revision"] + ":Rubi/IntegrationRules/" + file["source_path"]
        source = subprocess.check_output(["git", "-C", vendor, "show", blob], text=True)
        marker = "(* ::Code:: *)"
        cells = enumerate(source.split(marker)) if marker in source else enumerate(source.splitlines(), 1)
        wrapped = [i for i, text in cells if re.match(r"\s*If\[TrueQ\[\$LoadShowSteps\]", text)]
        if not wrapped:
            continue
        path = file["path"]
        shipped = json.loads((rules / path).read_text())
        plain = json.loads((edition / "rules" / path).read_text())
        section = shipped["section"]
        observed[section] = wrapped
        for ordinal in wrapped:
            rule_id = EXPECTED[section][ordinal]
            original = next(r for r in plain["rules"] if r["id"] == ordinal)
            actual = next(r for r in shipped["rules"] if r["id"] == rule_id)
            if canonical_payload(actual) != canonical_payload(original):
                raise ValueError(f"{section} source {ordinal} differs from distributed rule {rule_id}")
    if observed != {section: list(ids) for section, ids in EXPECTED.items()}:
        raise ValueError(f"Changed wrapped rule inventory: {observed}")
    print(f"{sum(map(len, observed.values()))} plain branches verified across {len(observed)} sections")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ("vendor", "edition", "rules"):
        parser.add_argument(arg, type=Path)
    args = parser.parse_args()
    check(args.vendor, args.edition, args.rules)
