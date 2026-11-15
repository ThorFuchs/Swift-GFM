#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Copy an upstream cmark-gfm checkout into Vendor/GitHubCMark and rewrite its manifest.

Copies `src/`, `extensions/` and `COPYING` unmodified, renders the version
header from upstream's template and CMake version variables, and records the
SHA-256 of every copied file. SwiftGFM's own files (`api/`, `bridge/`) and the
other generated headers are left alone. See Documentation/UPDATING-CMARK-GFM.md.
"""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
VENDOR = ROOT / "Vendor/GitHubCMark"
REPOSITORY = "https://github.com/github/cmark-gfm"


def version_header(checkout):
    cmake = (checkout / "CMakeLists.txt").read_text(encoding="utf-8")
    template = (checkout / "src/cmark-gfm_version.h.in").read_text(encoding="utf-8")
    for name in ("MAJOR", "MINOR", "PATCH", "GFM"):
        match = re.search(rf"set\(PROJECT_VERSION_{name} (\d+)\)", cmake)
        if not match:
            raise ValueError(f"PROJECT_VERSION_{name} not found in CMakeLists.txt")
        template = template.replace(f"@PROJECT_VERSION_{name}@", match.group(1))
    if "@" in template:
        raise ValueError("unexpanded variable in cmark-gfm_version.h.in")
    return template


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checkout", type=pathlib.Path, help="clean upstream cmark-gfm git checkout")
    args = parser.parse_args()
    checkout = args.checkout.resolve()
    status = subprocess.run(["git", "-C", str(checkout), "status", "--porcelain"], check=True,
                            capture_output=True, text=True).stdout
    if status:
        parser.error("the upstream checkout has local modifications")
    revision = subprocess.run(["git", "-C", str(checkout), "rev-parse", "HEAD"], check=True,
                              capture_output=True, text=True).stdout.strip()
    for folder in ("src", "extensions"):
        shutil.rmtree(VENDOR / folder)
        shutil.copytree(checkout / folder, VENDOR / folder)
    shutil.copyfile(checkout / "COPYING", VENDOR / "COPYING")
    (VENDOR / "generated/cmark-gfm_version.h").write_text(version_header(checkout), encoding="utf-8")
    files = sorted(p.relative_to(VENDOR).as_posix() for folder in ("src", "extensions")
                   for p in (VENDOR / folder).rglob("*") if p.is_file())
    files.append("COPYING")
    manifest = {"repository": REPOSITORY, "revision": revision,
                "files": {name: hashlib.sha256((VENDOR / name).read_bytes()).hexdigest() for name in sorted(files)}}
    (VENDOR / "UPSTREAM_SHA256.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Vendored cmark-gfm {revision}: {len(files)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
