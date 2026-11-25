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
  independent variables only with an `independence:` finding); `NeQ[a, b]` → `neq(a, b)` (`And` flattened, `Not[EqQ]` read as `NeQ`
  and `Not[NeQ]` as `EqQ`),
  `EqQ[a, b]` → `eq(a, b)`, `Sqrt[a]` → `root(a, 2)`, `E^u` → `exp(u)`, `Simp[e]` and `Simp[e, x]` → `e`, `Acoth[u]` → `arctanh(u^-1)`,
  `Subst[Int[H, x], x, g]` → `int(λx. H)(g)`, `Acot[u]` → `arctan(u^-1)`,
  the inert `sin`, `cos`, `tan`, `cot`, `sec`, `csc` → `Sin`, …, `Csc`,
  `GtQ[a, b]` → `gt(a, b)`, `LtQ[a, b]` → `gt(b, a)`, `GeQ[a, b]` and
  `Not[LtQ[a, b]]` → `geq(a, b)`, `LeQ[a, b]` and `Not[GtQ[a, b]]` → `geq(b, a)`,
  `Or[c, d, …]` → a left-nested `logic1#or`; compound conditions are put in conjunctive
  normal form (`cnf`: And flattens, Or distributes, Not moves inward), `IntegerQ[a]` and
  `IntegersQ[a, …]` → `in(a, Z)`, `IGtQ[n, k]` → `in(n, Z)`, `gt(n, k)`,
  `ILtQ[n, k]` → `in(n, Z)`, `gt(k, n)`, in constraint order.

A *strengthened* v1 rule (a corrected variant) may append conditions after the
converted ones, only with a `strengthened:` finding; it is counted separately.
An independently proved *generalized* derived variant may replace conditions
with a `generalized:` finding; its pattern and replacement must still match.
This check reports that distinction but does not verify the Lean proof.

Usage: scripts/v1_faithfulness.py [--rules rules] v1/integration.osr.json
Exit status 1 if a rule differs.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

BINARY = {("arith1", "plus"), ("arith1", "times")}
EXP = {"kind": "OMS", "cd": "transc1", "name": "exp"}
LAMBDA = {"kind": "OMS", "cd": "fns1", "name": "lambda"}
INT = {"kind": "OMS", "cd": "calculus1", "name": "int"}


def oms(uri: str) -> dict:
    cd, name = uri.removeprefix("openmath:").split("#")
    return {"kind": "OMS", "cd": cd, "name": name}


INERT_TRIG = {"sin": "Sin", "cos": "Cos", "tan": "Tan", "cot": "Cot", "sec": "Sec", "csc": "Csc"}
TRIG_SEMANTICS = {v: f"openmath:transc1#{k}" for k, v in INERT_TRIG.items()}


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
    # RUBI writes inert copies sin, cos, … of the trig functions in some rules; same value.
    head = INERT_TRIG.get(head, head)
    if head == "Int":
        return {"kind": "OMA",
                "applicant": {"kind": "OMA", "applicant": INT,
                              "arguments": [lam(var, convert(args[0], semantics, var))]},
                "arguments": [{"kind": "OMV", "name": var}]}
    if head == "Subst" and len(args) == 3 and isinstance(args[0], list) and args[0][0] == "Int":
        # Subst[Int[H, x], x, g]: an antiderivative of λx. H evaluated at g (V1-E-002b).
        if not (isinstance(args[1], str) and name(args[1]) == var and name(args[0][2]) == var):
            raise ValueError("no v1 counterpart for a Subst in another variable")
        return {"kind": "OMA",
                "applicant": {"kind": "OMA", "applicant": INT,
                              "arguments": [lam(var, convert(args[0][1], semantics, var))]},
                "arguments": [convert(args[2], semantics, var)]}
    if head == "Simp" and len(args) in (1, 2):
        # Simp[e] and Simp[e, x] only normalise e algebraically; the value is e.
        return convert(args[0], semantics, var)
    if head == "Acot" and len(args) == 1:
        # arccot(u) = arctan(1/u) (Mathematica's ArcCot, real and complex); the fragment has no arccot.
        return convert(["Atan", ["Power", args[0], -1]],
                       {**semantics, "Atan": "openmath:transc1#arctan", "Power": "openmath:arith1#power"}, var)
    if head == "Acoth" and len(args) == 1:
        # arccoth(u) = arctanh(1/u) (real and principal complex branches); the fragment has no arccoth.
        return convert(["Atanh", ["Power", args[0], -1]],
                       {**semantics, "Atanh": "openmath:transc1#arctanh", "Power": "openmath:arith1#power"}, var)
    if head == "Power" and len(args) == 2 and args[0] == "E":
        # E^u is the exponential: exp(u) (the v0.1 corpus writes exponentials so).
        return {"kind": "OMA", "applicant": EXP, "arguments": [convert(args[1], semantics, var)]}
    # a trig head may be missing from a file's semantics, which then lists only the
    # inert form (sin, as osr#sin): use the transc1 symbol of the trig function
    uri = semantics[head] if head in semantics else TRIG_SEMANTICS[head]
    if uri == "openmath:transc1#arctan" and len(args) != 1:
        raise ValueError(f"{uri} expects one operand, got {len(args)}")
    if uri == "openmath:transc2#arctan" and len(args) != 2:
        raise ValueError(f"{uri} expects two coordinates, got {len(args)}")
    symbol = oms(uri)
    converted = [convert(a, semantics, var) for a in args]
    if head == "Sqrt" and len(converted) == 1:
        converted.append({"kind": "OMI", "integer": 2})
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


NEGATE = {"EqQ": "NeQ", "NeQ": "EqQ", "LtQ": "GeQ", "GtQ": "LeQ", "GeQ": "LtQ", "LeQ": "GtQ"}
LITERALS = {"EqQ", "NeQ", "GtQ", "LtQ", "GeQ", "LeQ", "IntegerQ"}
MAX_CLAUSES = 16


def cnf(constraints):
    """v0.1 constraints -> (clauses, independent): a conjunctive normal form whose literals are
    EqQ, NeQ, GtQ, LtQ, GeQ, LeQ or one-argument IntegerQ.  And flattens, Or distributes over
    And, Not moves inward (De Morgan; Not of a comparison is the opposite comparison), IGtQ and
    ILtQ are IntegerQ and a comparison, IntegersQ is one IntegerQ per argument."""
    independent = set()

    def norm(c, neg=False, top=True):
        # -> list of clauses (each a list of literals); top: in the outer conjunction
        h, a = c[0], c[1:]
        if h == "FreeQ":
            if not top or neg:
                raise ValueError("no v1 counterpart for FreeQ under Or or Not")
            vs = a[0][1:] if isinstance(a[0], list) else [a[0]]
            independent.update(name(v) for v in vs)
            return []
        if h == "Not":
            return norm(a[0], not neg, False)
        if h == "IGtQ":
            c = ["And", ["IntegerQ", a[0]], ["GtQ", a[0], a[1]]]
            h, a = c[0], c[1:]
        elif h == "ILtQ":
            c = ["And", ["IntegerQ", a[0]], ["LtQ", a[0], a[1]]]
            h, a = c[0], c[1:]
        elif h == "IntegersQ":
            c = ["And"] + [["IntegerQ", z] for z in a]
            h, a = c[0], c[1:]
        if (h == "And") != neg and h in ("And", "Or"):
            return [cl for z in a for cl in norm(z, neg, top and not neg)]  # a conjunction
        if h in ("And", "Or"):  # a disjunction: distribute
            acc = [[]]
            for z in a:
                acc = [x + y for x in acc for y in norm(z, neg, False)]
                if len(acc) > MAX_CLAUSES:
                    raise ValueError("no v1 counterpart: the normal form is too large")
            return acc
        if h in LITERALS and not (h == "IntegerQ" and len(a) != 1):
            if neg:
                if h == "IntegerQ":
                    raise ValueError("no v1 counterpart for Not[IntegerQ]")
                return [[[NEGATE[h]] + list(a)]]
            return [[[h] + list(a)]]
        raise ValueError(f"no v1 counterpart for {h}")

    clauses = []
    for con in constraints:
        if con[0] == "FreeQ":
            vs = con[1][1:] if isinstance(con[1], list) else [con[1]]
            independent |= {name(v) for v in vs}
            continue
        clauses += norm(con)
    return clauses, independent


def conditions(constraints, semantics, var):
    c = lambda t: convert(t, semantics, var)

    def literal(lit):
        h, a = lit[0], lit[1:]
        if h == "NeQ": return rel("neq", c(a[0]), c(a[1]))
        if h == "EqQ": return rel("eq", c(a[0]), c(a[1]))
        if h == "GtQ": return rel("gt", c(a[0]), c(a[1]))
        if h == "LtQ": return rel("gt", c(a[1]), c(a[0]))
        if h == "GeQ": return rel("geq", c(a[0]), c(a[1]))
        if h == "LeQ": return rel("geq", c(a[1]), c(a[0]))
        if h == "IntegerQ": return in_z(c(a[0]))
        raise ValueError(f"no v1 counterpart for {h}")

    clauses, independent = cnf(constraints)
    out = []
    for cl in clauses:
        acc = literal(cl[0])
        for lit in cl[1:]:
            acc = {"kind": "OMA", "applicant": {"kind": "OMS", "cd": "logic1", "name": "or"},
                   "arguments": [acc, literal(lit)]}
        out.append(acc)
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
    ok, bad, strengthened, generalized = 0, 0, 0, 0
    for v1 in json.loads(args.ruleset.read_text())["rules"]:
        legacy = v1.get("legacy_id")
        if legacy is None or legacy not in corpus:
            print(f"{v1['id']}: no v0.1 rule {legacy}")
            bad += 1
            continue
        exp = expected(*corpus[legacy])
        problems = []
        for key in ("pattern", "replacement"):
            if v1[key] != exp[key]:
                problems.append(f"{key} differs")
        noted = any(f.startswith("strengthened:") for f in v1.get("findings", []))
        generalized_noted = any(f.startswith("generalized:") for f in v1.get("findings", []))
        proved = any(v.get("status") == "proved" and isinstance(v.get("theorem"), str)
                     and v["theorem"] for v in v1.get("verification", []))
        general = (generalized_noted and v1.get("provenance", {}).get("method") == "derived"
                   and proved)
        conds, base = v1["conditions"], exp["conditions"]
        added = noted and len(conds) > len(base) and conds[:len(base)] == base
        if generalized_noted and not general:
            problems.append("generalization requires derived provenance and a proved theorem")
        if generalized_noted and noted:
            problems.append("generalized and strengthened findings cannot be combined")
        if conds != base and not added and not general:
            problems.append("conditions differs")
        declared = {i["variable"] for i in v1.get("independent", [])}
        documented = any(f.startswith("independence:") for f in v1.get("findings", []))
        if not (declared == exp["independent"]
                or (declared > exp["independent"] and documented)):
            problems.append("independent differs")
        if problems:
            bad += 1
            print(f"{v1['id']} ({legacy}): " + ", ".join(problems))
        elif general:
            generalized += 1
        elif added:
            strengthened += 1
        else:
            ok += 1
    print(f"{ok} faithful, {strengthened} strengthened, {generalized} generalized, {bad} different")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
