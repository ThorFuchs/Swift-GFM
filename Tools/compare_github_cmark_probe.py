#!/usr/bin/env python3
"""Check a SwiftPM GitHub-C-source probe against its C CLI on source fixtures."""
import argparse
import base64
import hashlib
import json
import pathlib
import platform
import shlex
import subprocess
import sys
from compare_bundled_gfm import ROOT, SOURCES, extract

FORMATS = ("html", "xml", "commonmark", "plaintext", "latex", "man")

def execute(command, data):
    try:
        p = subprocess.run(command, input=data, capture_output=True, timeout=10)
        return p.returncode, p.stdout, p.stderr, None
    except (OSError, subprocess.TimeoutExpired) as exc:
        return None, b"", b"", str(exc)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--probe", required=True)
    p.add_argument("--reference", required=True)
    p.add_argument("--report", required=True)
    args = p.parse_args()
    filename, digest, revision = SOURCES["current"]
    fixture = (ROOT / "Fixtures/gfm" / filename).read_bytes()
    if hashlib.sha256(fixture).hexdigest() != digest:
        p.error("fixture checksum mismatch")
    cases = extract(fixture)
    enabled = [case for case in cases if "disabled" not in case["flags"]]
    results, failures = [], []
    for case in enabled:
        extargs = [arg for flag in case["flags"] for arg in ("-e", flag)]
        for fmt in FORMATS:
            reference_cmd = [args.reference, "--to", fmt, "--unsafe"] + extargs
            probe_cmd = [args.probe, fmt, "--unsafe"] + extargs
            reference = execute(reference_cmd, case["markdown"].encode("utf-8"))
            probe = execute(probe_cmd, case["markdown"].encode("utf-8"))
            match = reference[3] is None and probe[3] is None and reference[0] == probe[0] == 0 and reference[1] == probe[1]
            row = {"id": case["example"], "format": fmt, "extensions": case["flags"], "match": match,
                   "reference_exit": reference[0], "probe_exit": probe[0]}
            if not match:
                row.update({"input": case["markdown"], "reference_command": reference_cmd, "probe_command": probe_cmd,
                            "reference_stdout_base64": base64.b64encode(reference[1]).decode(),
                            "probe_stdout_base64": base64.b64encode(probe[1]).decode(),
                            "reference_stderr": reference[2].decode("utf-8", errors="backslashreplace"),
                            "probe_stderr": probe[2].decode("utf-8", errors="backslashreplace"),
                            "reference_error": reference[3], "probe_error": probe[3]})
                failures.append(row)
            results.append(row)
    counts = {fmt: {"total": sum(r["format"] == fmt for r in results),
                    "matched": sum(r["format"] == fmt and r["match"] for r in results)} for fmt in FORMATS}
    report = {"source_revision": revision, "fixture_sha256": digest,
              "reference_binary_sha256": hashlib.sha256(pathlib.Path(args.reference).read_bytes()).hexdigest(),
              "probe_binary_sha256": hashlib.sha256(pathlib.Path(args.probe).read_bytes()).hexdigest(),
              "python_version": platform.python_version(), "platform": platform.platform(),
              "reproduce": shlex.join([sys.executable, *sys.argv]),
              "comparison": "Exact stdout bytes and successful process status. Reference CLI and Swift probe both use --unsafe and the source example's extension flags, with default width. Not a complete API, option, concurrency or spec conformance test.",
              "source_example_count": len(cases), "upstream_disabled_examples": [x["example"] for x in cases if "disabled" in x["flags"]],
              "counts": counts, "failures": failures, "results": results}
    path = pathlib.Path(args.report)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    for fmt, count in counts.items():
        print(f"{fmt}: {count['matched']}/{count['total']} byte-identical")
    print(f"source-disabled examples excluded: {report['upstream_disabled_examples']}")
    return 1 if failures else 0

if __name__ == "__main__":
    sys.exit(main())
