"""Build the reference edition from the exact posthumous RUBI 4.17.3.0 release."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile

from audit_rubi_order import audit_order
from check_duplicate_rules import canonical_payload

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.17.3.0"
RELEASE = "f7fa0fd7bfacd326bc9e125473c5bad41cfad4e4"
PACLET_SHA256 = "7949302d5988865222516ed27e29128b0e82e65f266b1ef344bda9bd2e3a11c5"


def source(vendor, path):
    return subprocess.check_output(["git", "-C", vendor, "show", f"{RELEASE}:Rubi/{path}"])


def verify_archive(archive, files, vendor):
    if hashlib.sha256(archive.read_bytes()).hexdigest() != PACLET_SHA256:
        raise ValueError("Official paclet SHA-256 mismatch")
    with zipfile.ZipFile(archive) as package:
        for path in files:
            if package.read(f"Rubi-{VERSION}/{path}") != source(vendor, path):
                raise ValueError(f"Release Git blob differs from the paclet: {path}")


def build(vendor, output, archive):
    if output.exists():
        raise ValueError(f"Output already exists: {output}")
    metadata = json.loads((ROOT / "rules/meta.json").read_text())
    documents = {}
    for path in metadata["load_order"]:
        doc = json.loads((ROOT / "rules" / path).read_text())
        identity = doc["identity"].removeprefix("rubi:")
        if identity in documents:
            raise ValueError(f"Duplicate Rubi source path: {identity}")
        documents[identity] = (path, [])
    order = audit_order(source(vendor, "Rubi.m").decode(), documents)["files"]
    inputs = ["PacletInfo.m", "Rubi.m", "IntegrationUtilityFunctions.m"]
    inputs.extend("IntegrationRules/" + item["source"] + ".m" for item in order)
    if archive:
        verify_archive(archive, inputs, vendor)
    release = dict(version=VERSION, revision=RELEASE, load_order=[r["osr_file"] for r in order])
    # Build next to the destination so that conversion errors leave no partial edition.
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent) as tmp:
        descriptor = Path(tmp) / "release.json"
        descriptor.write_text(json.dumps(release))
        edition = Path(tmp) / "edition"
        subprocess.run(["julia", "--project=" + str(ROOT / "converter"),
                        ROOT / "converter/scripts/source-edition.jl", vendor, edition, descriptor], check=True)
        license_text = subprocess.check_output(["git", "-C", vendor, "show", f"{RELEASE}:LICENSE"])
        (edition / "LICENSE").write_bytes(license_text)
        errata = json.loads((ROOT / "docs/rubi-errata.json").read_text())
        mapped = []
        for issue in errata:
            if issue["source_revision"] != RELEASE:
                continue
            doc = json.loads((edition / "rules" / issue["file"]).read_text())
            ids = {r["id"] for r in doc["rules"]}
            if issue["action"] == "enable":
                # A guarded source rule the edition omits: its ID is free and its
                # insertion point is shipped.
                if (doc["identity"] != issue["file_identity"] or issue["rule_id"] in ids
                        or issue["insert_before"] not in ids):
                    raise ValueError(f"Release erratum requires review: {issue['file']}")
                mapped.append(issue)
                continue
            rule = next(r for r in doc["rules"] if r["id"] == issue["rule_id"])
            digest = hashlib.sha256(canonical_payload(rule).encode()).hexdigest()
            if doc["identity"] != issue["file_identity"] or digest != issue["payload_sha256"]:
                raise ValueError(f"Release erratum requires review: {issue['file']}")
            mapped.append(issue)
        (edition / "errata.json").write_text(json.dumps(mapped, indent=2) + "\n")
        edition.rename(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vendor", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--paclet", type=Path, help="also compare every required input with the release asset")
    args = parser.parse_args()
    build(args.vendor.resolve(), args.output.resolve(), args.paclet)
