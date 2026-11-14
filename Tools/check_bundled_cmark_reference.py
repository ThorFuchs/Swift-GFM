#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare wrapper and independently built pinned cmark on bundled test inputs."""
import argparse
import base64
from collections import Counter
import hashlib
import json
import pathlib
import platform
import shlex
import subprocess
import sys

from bundled_cmark_fixtures import DIRECTORY, REVISION, SOURCES, extract

FORMATS = ("html", "xml", "commonmark", "plaintext", "latex", "man")
ALL_EXTENSIONS = ("table", "strikethrough", "autolink", "tagfilter", "footnotes", "tasklist")


def command_options(suite, flags):
    extensions = list(flags)
    options = ["--unsafe"]
    if suite in ("extensions", "extensions-table-prefer-style-attributes"):
        extensions.extend(ALL_EXTENSIONS)
    if suite == "smart_punct":
        options.append("--smart")
    if suite == "extensions-full-info-string":
        options.append("--full-info-string")
    if suite == "extensions-table-prefer-style-attributes":
        options.append("--table-prefer-style-attributes")
    return options + [part for extension in dict.fromkeys(extensions) for part in ("-e", extension)]


def run(command, data):
    try:
        proc = subprocess.run(command, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
        return {"status": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr, "error": None}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"status": None, "stdout": b"", "stderr": b"", "error": str(error)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", required=True)
    parser.add_argument("--reference", required=True)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    results = []
    disabled = []
    for suite, (digest, _) in SOURCES.items():
        source = (DIRECTORY / f"{suite}.txt").read_bytes()
        if hashlib.sha256(source).hexdigest() != digest:
            parser.error(f"fixture hash mismatch: {suite}")
        for case in extract(source):
            if "disabled" in case["flags"]:
                disabled.append(f"{suite}#{case['example']}")
                continue
            opts = command_options(suite, case["flags"])
            for fmt in FORMATS:
                reference_command = [args.reference, "--to", fmt] + opts
                probe_command = [args.probe, fmt] + opts
                reference = run(reference_command, case["markdown"].encode("utf-8"))
                actual = run(probe_command, case["markdown"].encode("utf-8"))
                match = (reference["status"] == actual["status"] == 0 and not reference["error"]
                         and not actual["error"] and reference["stdout"] == actual["stdout"])
                row = {"suite": suite, "id": case["example"], "format": fmt, "match": match}
                if not match:
                    row.update({"markdown": case["markdown"], "reference_command": reference_command,
                                "probe_command": probe_command, "reference_exit": reference["status"],
                                "probe_exit": actual["status"], "reference_error": reference["error"],
                                "probe_error": actual["error"],
                                "reference_stdout_base64": base64.b64encode(reference["stdout"]).decode(),
                                "probe_stdout_base64": base64.b64encode(actual["stdout"]).decode(),
                                "reference_stderr": reference["stderr"].decode("utf-8", errors="backslashreplace"),
                                "probe_stderr": actual["stderr"].decode("utf-8", errors="backslashreplace")})
                results.append(row)
    failures = [row for row in results if not row["match"]]
    per_suite = Counter(row["suite"] for row in results if row["match"])
    report = {"cmark_revision": REVISION,
              "scope": "Exact stdout bytes against an independently built C executable; all enabled bundled inputs and six formats. Includes extensions#20, whose upstream expected HTML is <IGNORE>. Binary hash does not establish source provenance.",
              "fixture_sha256": {suite: digest for suite, (digest, _) in SOURCES.items()},
              "reproduction": shlex.join([sys.executable, *sys.argv]),
              "reference_sha256": hashlib.sha256(pathlib.Path(args.reference).read_bytes()).hexdigest(),
              "probe_sha256": hashlib.sha256(pathlib.Path(args.probe).read_bytes()).hexdigest(),
              "python": platform.python_version(), "total": len(results), "passed": len(results) - len(failures),
              "failed": len(failures), "disabled": disabled, "passed_by_suite": dict(per_suite), "results": results}
    pathlib.Path(args.report).write_text(json.dumps(report, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print(f"Bundled backend parity: {report['passed']}/{report['total']} matched; {report['failed']} failed; disabled: {disabled}")
    for row in failures[:20]:
        print(f"  {row['suite']}#{row['id']} {row['format']}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
