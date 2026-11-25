"""Extract the four arithmetic logabs assertions from Maxima bug 5244."""
import ast
import hashlib
import json
import re
import sys
from pathlib import Path

REVISION = "8806ad76963d385137fc8b5198746f98565b3f61"
DIGEST = "1448fb8583d1e5be8820292567f6b5e28a819271e0e785d5b4035bcd1982d37e"


def expr(node):
    if isinstance(node, ast.BinOp):
        names = {ast.Add: "Add", ast.Sub: "Subtract", ast.Mult: "Multiply",
                 ast.Div: "Divide", ast.Pow: "Power"}
        return [names[type(node.op)], expr(node.left), expr(node.right)]
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
        return ["Negate", expr(node.operand)]
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and len(node.args) == 1 and not node.keywords:
        name = {"sqrt": "Sqrt", "log": "Log", "abs": "Abs"}[node.func.id]
        return [name, expr(node.args[0])]
    if isinstance(node, ast.Name) and node.id in ("a", "x", "I"):
        return node.id
    if isinstance(node, ast.Constant) and type(node.value) is int:
        return node.value
    raise ValueError(ast.dump(node))


def parse(text):
    # The four source expressions use only ^, %i and this shared arithmetic subset.
    return expr(ast.parse(text.replace("^", "**").replace("%i", "I"), mode="eval").body)


def nonzero_real(term):
    return ["Or", ["GtQ", term, 0], ["LtQ", term, 0]]


def build(source):
    if hashlib.sha256(source).hexdigest() != DIGEST:
        raise ValueError("Unexpected Maxima source SHA-256")
    lines = source.decode().splitlines()
    common = [["EqQ", ["Im", "x"], 0]]
    constant = ["FreeQ", "a", "x"]
    tests = []
    for id_, line, guards in [
        ("imaginary-shift", 6896, []),
        ("real-reciprocal", 6899, [nonzero_real("x")]),
        ("nested-root", 6902, [constant, ["LtQ", "a", 0], nonzero_real("x")]),
        ("real-split-poles", 6905, [constant, nonzero_real("a"), nonzero_real(["Subtract", "x", "a"]),
                                    nonzero_real(["Add", "x", "a"])]),
    ]:
        assertion = re.fullmatch(r"integrate\((.+),x\), logabs;", lines[line-1])
        result = re.fullmatch(r"(.+);", lines[line])
        if not assertion or not result:
            raise ValueError(f"Expected integration and result at source line {line}")
        tests.append(dict(id=id_, source_lines=[line, line+1], variable="x", constraints=common + guards,
                          expression=parse(assertion[1]), expected_result=parse(result[1])))
    return dict(source="https://github.com/calyau/maxima", revision=REVISION, path="tests/rtest_integrate.mac",
                source_sha256=DIGEST, license="GPL-2.0-only", license_file="../maxima/COPYING", tests=tests)


if __name__ == "__main__":
    data = build(Path(sys.argv[1]).read_bytes())
    print("{")
    for field, item in data.items():
        if field != "tests":
            print(f"  {json.dumps(field)}: {json.dumps(item)},")
    print('  "tests": [')
    records = ["    {\n" + ",\n".join(f"      {json.dumps(k)}: {json.dumps(v)}" for k,v in c.items())
               + "\n    }" for c in data["tests"]]
    print(",\n".join(records))
    print("  ]\n}")
