#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check fixture extraction against the pinned upstream get_tests implementation."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import sys

from bundled_cmark_fixtures import DIRECTORY, SOURCES, extract


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream-test-dir", required=True)
    args = parser.parse_args()
    upstream = pathlib.Path(args.upstream_test_dir)
    total = 0
    for suite, (digest, _) in SOURCES.items():
        raw = (DIRECTORY / f"{suite}.txt").read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            parser.error(f"fixture hash mismatch: {suite}")
        command = [sys.executable, str(upstream / "spec_tests.py"), "--spec", str(DIRECTORY / f"{suite}.txt"), "--dump-tests"]
        reference = json.loads(subprocess.run(command, check=True, capture_output=True).stdout)
        actual = [x for x in extract(raw) if "disabled" not in x["flags"]]
        if len(reference) != len(actual):
            print(f"{suite}: count mismatch: upstream {len(reference)}, local {len(actual)}")
            return 1
        for original, local in zip(reference, actual):
            for upstream_key, local_key in (("example", "example"), ("section", "section"),
                                            ("markdown", "markdown"), ("html", "html"), ("extensions", "flags")):
                if original[upstream_key] != local[local_key]:
                    print(f"{suite}#{local['example']}: {upstream_key} differs")
                    return 1
        total += len(actual)
        print(f"{suite}: {len(actual)}/{len(reference)} upstream examples matched")
    print(f"{total} source-enabled examples matched upstream extraction")
    return 0


if __name__ == "__main__":
    sys.exit(main())
