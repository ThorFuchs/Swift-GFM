#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check that every mention of the pinned cmark-gfm revision and version is current.

The vendored source manifest and generated version header are the single source
of truth. Tools read them directly; this check covers the places that must
state the revision or version literally, such as Swift code and documentation.
"""
import pathlib
import re
import subprocess
import sys

from bundled_cmark_fixtures import REVISION, ROOT, VERSION

# Files that must state the current revision literally.
REQUIRED = (
    "Sources/SwiftGFM/SwiftGFM.swift",
    "README.md",
    "NOTICE",
    "Documentation/BUNDLED-CMARK-QA.md",
    "Sources/SwiftGFM/SwiftGFM.docc/BundledConformance.md",
    "Tests/SwiftGFMTests/Fixtures/cmark-gfm/README.md",
    "Tests/SwiftGFMTests/Fixtures/cmark-gfm/entities-reference.json",
)
VERSION_PATTERN = re.compile(r"\b\d+\.\d+\.\d+\.gfm\.\d+\b")
REVISION_PATTERN = re.compile(r"github/cmark-gfm[^\s)\"'`]*?([0-9a-f]{40})|\b([0-9a-f]{40})\b")


def tracked_files(root):
    output = subprocess.run(["git", "-C", str(root), "ls-files", "-z"], check=True, capture_output=True).stdout
    for name in output.decode().split("\0"):
        if name and not name.startswith("Vendor/"):
            yield name


def problems(root, files, revision, version):
    """Return human-readable mismatches between files and the pinned values."""
    found = []
    for name in REQUIRED:
        if revision not in (root / name).read_text(encoding="utf-8"):
            found.append(f"{name}: does not mention the pinned revision {revision}")
    swift = (root / "Sources/SwiftGFM/SwiftGFM.swift").read_text(encoding="utf-8")
    if f'backendRevision = "{revision}"' not in swift:
        found.append("Sources/SwiftGFM/SwiftGFM.swift: backendRevision is not the pinned revision")
    for name in files:
        path = root / name
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
            continue
        for line_number, line in enumerate(text.splitlines(), 1):
            for match in VERSION_PATTERN.finditer(line):
                if match.group(0) != version:
                    found.append(f"{name}:{line_number}: version {match.group(0)} is not {version}")
            if "cmark" not in line.lower() and "revision" not in line.lower():
                continue
            for match in REVISION_PATTERN.finditer(line):
                value = match.group(1) or match.group(2)
                if value != revision:
                    found.append(f"{name}:{line_number}: revision {value} is not {revision}")
    return found


def main():
    found = problems(ROOT, list(tracked_files(ROOT)), REVISION, VERSION)
    for problem in found:
        print(problem)
    print(f"Pinned cmark-gfm {VERSION} at {REVISION}: {len(found)} inconsistencies")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
