#!/usr/bin/env python3
"""Reproduce reference comparisons for the 15 published GFM mapping gaps."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import sys
from gfm_fixtures import extract

ROOT = pathlib.Path(__file__).resolve().parents[1]
CASES = {83: None, 87: None, 279: "tasklist", 280: "tasklist", 324: None,
         491: "strikethrough", 493: "strikethrough", 544: None, 549: None,
         625: "autolink", 629: "autolink", 633: "autolink", 634: "autolink",
         635: "autolink", 665: None}
DIGEST = "b153d814fdfc8624bb6da7449162c1cd707a637f7d1c1b636eb44b9cf63fa220"

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--historical", required=True, help="cmark-gfm 0.29.0.gfm.0 executable")
    parser.add_argument("--current", required=True, help="pinned cmark-gfm 0.29.0.gfm.13 executable")
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    raw = (ROOT / "Fixtures/gfm/spec.html").read_bytes()
    if hashlib.sha256(raw).hexdigest() != DIGEST:
        parser.error("published specification checksum mismatch")
    fixtures = {x["example"]: x for x in extract(raw)}
    rows = []
    for number, extension in CASES.items():
        case = fixtures[number]
        row = {"id": number, "extension": extension, "markdown": case["markdown"],
               "expected": case["html"], "references": {}}
        for label, binary in (("historical", args.historical), ("current", args.current)):
            cmd = [binary, "--unsafe"] + (["-e", extension] if extension else [])
            try:
                proc = subprocess.run(cmd, input=case["markdown"].encode(), capture_output=True, timeout=10)
                actual = proc.stdout.decode("utf-8")
                row["references"][label] = {"command": cmd, "returncode": proc.returncode,
                    "actual": actual, "stderr": proc.stderr.decode("utf-8", errors="replace"),
                    "matches": proc.returncode == 0 and proc.stdout == case["html"].encode()}
            except (OSError, UnicodeDecodeError, subprocess.TimeoutExpired) as error:
                row["references"][label] = {"command": cmd, "error": str(error), "matches": False}
        rows.append(row)
    report = {"fixture_sha256": DIGEST, "historical_revision": "b8eb2e00de094999f978e9cb02b1a78d810812d3", "current_revision": "27d942c8b0a62d192f616e5bf3578f4b6a89e180", "note": "Revisions identify intended executables, not automatically verified binaries. Extension choices are investigation settings, not a global-profile conformance result.", "cases": rows}
    path = pathlib.Path(args.report)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    for label in ("historical", "current"):
        print(f"{label}: {sum(row['references'][label]['matches'] for row in rows)}/{len(rows)} exact matches")
    return 0 if all('error' not in ref for row in rows for ref in row['references'].values()) else 1

if __name__ == "__main__":
    sys.exit(main())
