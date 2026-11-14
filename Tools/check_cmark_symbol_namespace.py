#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check the linked C target object's global symbol namespace on Linux."""
import argparse
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
BRIDGE_SYMBOLS = {"swiftgfm_bridge_node_get_type", "swiftgfm_bridge_node_get_list_type", "swiftgfm_bridge_node_get_list_delim"}

def names():
    manifest = (ROOT / "Package.swift").read_text()
    match = re.search(r'private let cmarkSymbols = """\n(.*?)\n"""', manifest, re.S)
    if not match:
        raise ValueError("could not find the C symbol map in Package.swift")
    values = match.group(1).split()
    if not values or len(values) != len(set(values)):
        raise ValueError("empty or duplicate C symbols")
    return values

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("object", help="SwiftPM-produced GitHubCMark.o")
    args = parser.parse_args()
    output = subprocess.run(["nm", "-g", "--defined-only", args.object], capture_output=True, text=True, check=True).stdout
    actual = {line.split()[-1] for line in output.splitlines() if len(line.split()) >= 3}
    expected = {"swiftgfm_" + value for value in names()} | BRIDGE_SYMBOLS
    missing, extra = sorted(expected - actual), sorted(actual - expected)
    print(f"{len(actual)} defined globals; {len(expected)} expected prefixed globals; {len(missing)} missing; {len(extra)} unexpected")
    if missing: print("missing:", ", ".join(missing))
    if extra: print("unexpected:", ", ".join(extra))
    return 1 if missing or extra else 0

if __name__ == "__main__":
    raise SystemExit(main())
