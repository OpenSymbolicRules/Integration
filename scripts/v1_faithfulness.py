#!/usr/bin/env python3
"""Check that the OSR v1 rules transcribe their v0.1 RUBI rules faithfully.

Each v1 rule with a `legacy_id` is compared with the OpenMath objects the
v0.1 rule converts to under the documented conventions (docs/osr-v1.md):

* `Int[F, x]` → `int(λx. F)`; the result becomes `λx. G`, each residual
  `Int[H, x]` in `G` becoming `int(λx. H)(x)`;
* an n-ary `Add` or `Multiply` (any symbol the fragment uses as binary)
  becomes a left-nested chain; other heads keep their arguments;
* a wildcard (`a_`, `a.`, `x_symbol`) becomes the variable `a`;
* `FreeQ[{…}, x]` becomes `independent` (a v1 rule may declare more
  independent variables only with an `independence:` finding); `NeQ[a, b]` → `neq(a, b)`,
  `GtQ[a, b]` → `gt(a, b)`, `LtQ[a, b]` → `gt(b, a)`, `IntegerQ[a]` and
  `IntegersQ[a, …]` → `in(a, Z)`, `IGtQ[n, k]` → `in(n, Z)`, `gt(n, k)`,
  `ILtQ[n, k]` → `in(n, Z)`, `gt(k, n)`, in constraint order.

Usage: scripts/v1_faithfulness.py [--rules rules] v1/integration.osr.json
Exit status 1 if a rule differs.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

BINARY = {("arith1", "plus"), ("arith1", "times")}
LAMBDA = {"kind": "OMS", "cd": "fns1", "name": "lambda"}
INT = {"kind": "OMS", "cd": "calculus1", "name": "int"}


def oms(uri: str) -> dict:
    cd, name = uri.removeprefix("openmath:").split("#")
    return {"kind": "OMS", "cd": cd, "name": name}


def name(atom: str) -> str:
    return atom.split("_")[0].rstrip(".")


def lam(var: str, body: dict) -> dict:
    return {"kind": "OMBIND", "binder": LAMBDA, "variables": [{"kind": "OMV", "name": var}],
            "object": body}


def convert(term, semantics: dict, var: str) -> dict:
    if isinstance(term, bool):
        raise ValueError(f"boolean {term}")
    if isinstance(term, int):
        return {"kind": "OMI", "integer": term}
    if isinstance(term, str):
        return {"kind": "OMV", "name": name(term)}
    head, args = term[0], term[1:]
    if head == "Int":
        return {"kind": "OMA",
                "applicant": {"kind": "OMA", "applicant": INT,
                              "arguments": [lam(var, convert(args[0], semantics, var))]},
                "arguments": [{"kind": "OMV", "name": var}]}
    symbol = oms(semantics[head])
    converted = [convert(a, semantics, var) for a in args]
    if (symbol["cd"], symbol["name"]) in BINARY and len(converted) > 2:
        acc = converted[0]
        for nxt in converted[1:]:
            acc = {"kind": "OMA", "applicant": symbol, "arguments": [acc, nxt]}
        return acc
    return {"kind": "OMA", "applicant": symbol, "arguments": converted}


def rel(rel_name: str, a: dict, b: dict) -> dict:
    return {"kind": "OMA", "applicant": {"kind": "OMS", "cd": "relation1", "name": rel_name},
            "arguments": [a, b]}


def in_z(a: dict) -> dict:
    return {"kind": "OMA", "applicant": {"kind": "OMS", "cd": "set1", "name": "in"},
            "arguments": [a, {"kind": "OMS", "cd": "setname1", "name": "Z"}]}


def conditions(constraints, semantics, var):
    out, independent = [], set()
    c = lambda t: convert(t, semantics, var)
    for con in constraints:
        head, args = con[0], con[1:]
        if head == "FreeQ":
            vs = args[0][1:] if isinstance(args[0], list) else [args[0]]
            independent |= {name(v) for v in vs}
        elif head == "NeQ":
            out.append(rel("neq", c(args[0]), c(args[1])))
        elif head == "GtQ":
            out.append(rel("gt", c(args[0]), c(args[1])))
        elif head == "LtQ":
            out.append(rel("gt", c(args[1]), c(args[0])))
        elif head in ("IntegerQ", "IntegersQ"):
            out.extend(in_z(c(a)) for a in args)
        elif head == "IGtQ":
            out += [in_z(c(args[0])), rel("gt", c(args[0]), c(args[1]))]
        elif head == "ILtQ":
            out += [in_z(c(args[0])), rel("gt", c(args[1]), c(args[0]))]
        else:
            raise ValueError(f"no v1 counterpart for {head}")
    return out, independent


def expected(rule: dict, semantics: dict) -> dict:
    pattern = rule["pattern"]
    assert pattern[0] == "Int"
    var = name(pattern[2])
    conds, independent = conditions(rule.get("constraints", []), semantics, var)
    return {
        "pattern": {"kind": "OMA", "applicant": INT,
                    "arguments": [lam(var, convert(pattern[1], semantics, var))]},
        "replacement": lam(var, convert(rule["result"], semantics, var)),
        "conditions": conds,
        "independent": independent,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    root = Path(__file__).resolve().parent.parent
    parser.add_argument("--rules", type=Path, default=root / "rules")
    parser.add_argument("ruleset", type=Path)
    args = parser.parse_args(argv)
    corpus = {}
    for path in sorted(args.rules.rglob("*.json")):
        if path.name == "meta.json":
            continue
        document = json.loads(path.read_text())
        for rule in document.get("rules", []):
            corpus[f"{document.get('identity', path.stem)}:{rule['id']}"] = (
                rule, document.get("semantics", {}))
    ok, bad = 0, 0
    for v1 in json.loads(args.ruleset.read_text())["rules"]:
        legacy = v1.get("legacy_id")
        if legacy is None or legacy not in corpus:
            print(f"{v1['id']}: no v0.1 rule {legacy}")
            bad += 1
            continue
        exp = expected(*corpus[legacy])
        problems = []
        for key in ("pattern", "replacement", "conditions"):
            if v1[key] != exp[key]:
                problems.append(f"{key} differs")
        declared = {i["variable"] for i in v1.get("independent", [])}
        documented = any(f.startswith("independence:") for f in v1.get("findings", []))
        if not (declared == exp["independent"]
                or (declared > exp["independent"] and documented)):
            problems.append("independent differs")
        if problems:
            bad += 1
            print(f"{v1['id']} ({legacy}): " + ", ".join(problems))
        else:
            ok += 1
    print(f"{ok} faithful, {bad} different")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
