#!/usr/bin/env python3
"""Compare successful CLI options and six renderers for a small fixed corpus."""
import argparse
import base64
import hashlib
import json
import pathlib
import shlex
import subprocess
import sys
from compare_github_cmark_probe import FORMATS, execute

OPTIONS = [[], ["--unsafe"], ["--sourcepos"], ["--hardbreaks"], ["--nobreaks"],
           ["--smart"], ["--validate-utf8"], ["--github-pre-lang"], ["--liberal-html-tag"],
           ["--strikethrough-double-tilde"], ["--table-prefer-style-attributes"],
           ["--full-info-string"], ["--width", "40"], ["-e", "footnotes"]]
INPUTS = {
    "mixed": b'# Heading\n\nText\nline & <script> and www.example.com.\n\n- [x] ~~item~~\n\n| x | y |\n| - | :-: |\n| a | b |\n\n```swift extra\nlet x = 1\n```\n\n[^a]: note\n\n[^a]\n',
    "utf8-and-nul": 'A € and \x00 and ~~word~~.\n'.encode("utf-8"),
    "invalid-utf8": b'bad \xff utf8\n',
}
EXTS = [[], ["-e", "table", "-e", "strikethrough", "-e", "tasklist", "-e", "autolink", "-e", "tagfilter"]]

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--probe", required=True); p.add_argument("--reference", required=True); p.add_argument("--report", required=True)
    p.add_argument("--valid-utf8-only", action="store_true", help="exclude invalid-byte input for a String-based wrapper")
    args = p.parse_args()
    rows = []
    for name, data in INPUTS.items():
        if args.valid_utf8_only and name == "invalid-utf8":
            continue
        for options in OPTIONS:
            for extensions in EXTS:
                for fmt in FORMATS:
                    reference_cmd = [args.reference, "--to", fmt] + options + extensions
                    probe_cmd = [args.probe, fmt] + options + extensions
                    a, b = execute(reference_cmd, data), execute(probe_cmd, data)
                    match = a[3] is None and b[3] is None and a[0] == b[0] == 0 and a[1] == b[1]
                    row = {"input_id": name, "format": fmt, "options": options, "extensions": extensions,
                           "match": match, "reference_exit": a[0], "probe_exit": b[0]}
                    if not match:
                        row.update({"input_base64": base64.b64encode(data).decode(), "reference_command": reference_cmd, "probe_command": probe_cmd,
                                    "reference_stdout_base64": base64.b64encode(a[1]).decode(), "probe_stdout_base64": base64.b64encode(b[1]).decode(),
                                    "reference_error": a[3], "probe_error": b[3],
                                    "reference_stderr": a[2].decode("utf-8", errors="backslashreplace"), "probe_stderr": b[2].decode("utf-8", errors="backslashreplace")})
                    rows.append(row)
    count = sum(row['match'] for row in rows)
    report = {"scope": "Exploratory exact-output comparisons for selected byte inputs, individual option settings, and two extension sets. Not exhaustive, a conformance claim, or a concurrency test.",
              "valid_utf8_only": args.valid_utf8_only,
              "probe_sha256": hashlib.sha256(pathlib.Path(args.probe).read_bytes()).hexdigest(),
              "reference_sha256": hashlib.sha256(pathlib.Path(args.reference).read_bytes()).hexdigest(),
              "reproduce": shlex.join([sys.executable, *sys.argv]), "total": len(rows), "matched": count, "results": rows}
    dest = pathlib.Path(args.report);dest.parent.mkdir(parents=True, exist_ok=True);dest.write_text(json.dumps(report, indent=2) + "\n")
    print(f"{count}/{len(rows)} option/render/input combinations matched")
    return 1 if count != len(rows) else 0

if __name__ == '__main__':
    sys.exit(main())
