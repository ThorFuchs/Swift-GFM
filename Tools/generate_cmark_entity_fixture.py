#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Generate/check strict entity expectations from the pinned cmark-gfm CLI."""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Vendor/GitHubCMark/src/entities.inc"
DESTINATION = ROOT / "Tests/SwiftGFMTests/Fixtures/cmark-gfm/entities-reference.json"
REVISION = "27d942c8b0a62d192f616e5bf3578f4b6a89e180"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", required=True, help="independently built pinned cmark-gfm executable")
    parser.add_argument("--check", action="store_true", help="compare to the checked-in fixture without writing")
    args = parser.parse_args()
    raw = SOURCE.read_bytes()
    entries = re.findall(rb'^\{\(unsigned char\*\)"([^"]+)", \{([^}]+)\}', raw, re.MULTILINE)
    if len(entries) != 2125:
        parser.error(f"unexpected entity count: {len(entries)}")
    rows = []
    for name_bytes, _ in entries:
        name = name_bytes.decode("ascii")
        result = subprocess.run([args.reference, "--unsafe"], input=b"&" + name_bytes + b";",
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=10)
        rows.append({"name": name, "html": result.stdout.decode("utf-8")})
    payload = {"revision": REVISION, "entities_source_sha256": hashlib.sha256(raw).hexdigest(),
               "reference_options": ["--unsafe"], "examples": rows}
    generated = (json.dumps(payload, ensure_ascii=True, indent=2) + "\n").encode("utf-8")
    if args.check:
        if DESTINATION.read_bytes() != generated:
            raise SystemExit("Entity fixture differs from the reference executable")
        print(f"Verified {len(rows)} exact entity outputs")
    else:
        DESTINATION.write_bytes(generated)
        print(f"Wrote {len(rows)} exact entity outputs to {DESTINATION}")


if __name__ == "__main__":
    main()
