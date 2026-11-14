#!/usr/bin/env python3
"""Strict, byte-for-byte comparison of a command with official JSON examples."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import sys
import shlex
import platform
from gfm_fixtures import extract
from gfm_source_map import map_evidence
from gfm_published_config import OVERRIDES
from html_diagnostics import compare as compare_html_tokens

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPECS = {
    "commonmark": (ROOT / "Fixtures/commonmark/spec.json", "d431b29d97b6f73e69d547109cf5081578fac931e72afe95639ebe766c1b2a20", "CommonMark 0.31.2", "https://spec.commonmark.org/0.31.2/spec.json"),
    "gfm": (ROOT / "Fixtures/gfm/spec.html", "b153d814fdfc8624bb6da7449162c1cd707a637f7d1c1b636eb44b9cf63fa220", "GFM 0.29-gfm", "https://github.github.com/gfm/"),
}


def run(fixtures, command, timeout):
    results = []
    for case in fixtures:
        record = {"id": case["example"], "section": case["section"],
                  "markdown": case["markdown"], "expected": case["html"],
                  "actual": None, "classification": "unclassified"}
        try:
            p = subprocess.run(command, input=case["markdown"].encode(),
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
            record["exit_code"] = p.returncode
            record["stderr"] = p.stderr.decode("utf-8", errors="backslashreplace")
            try:
                record["actual"] = p.stdout.decode("utf-8")
            except UnicodeDecodeError:
                record["stdout_hex"] = p.stdout.hex()
            record["status"] = "pass" if p.returncode == 0 and p.stdout == case["html"].encode() else "fail"
        except subprocess.TimeoutExpired:
            record.update(status="fail", error="process timed out")
        except OSError as e:
            record.update(status="fail", error=str(e))
        results.append(record)
    return results


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("profile", choices=list(SPECS))
    p.add_argument("--view", choices=["diagnostic", "published", "fixed"], default="diagnostic", help="GFM reporting scope; fixed uses one unchanged command")
    p.add_argument("--report", required=True, help="JSON report path; a .txt report is also written")
    p.add_argument("--timeout", type=float, default=10)
    p.add_argument("--example", help="run one original fixture identifier")
    p.add_argument("--gfm-historical-extension-map", action="store_true", help="for cmark-gfm: use only extension flags from matching historical source examples; unmatched examples are explicitly skipped")
    p.add_argument("--renderer-version", default="unspecified", help="exact renderer revision/version for provenance")
    if "--" not in sys.argv:
        p.error("separate the renderer command with --")
    separator = sys.argv.index("--")
    args = p.parse_args(sys.argv[1:separator])
    command = sys.argv[separator + 1:]
    if not command or args.timeout <= 0:
        p.error("a command and a positive timeout are required")
    fixture, digest, version, url = SPECS[args.profile]
    raw = fixture.read_bytes()
    if hashlib.sha256(raw).hexdigest() != digest:
        p.error("fixture checksum mismatch")
    fixtures = json.loads(raw) if args.profile == "commonmark" else extract(raw)
    if args.view != "diagnostic" and args.profile != "gfm":
        p.error("published and fixed views currently support only gfm")
    if args.view != "diagnostic" and args.gfm_historical_extension_map:
        p.error("the historical map option is only available in diagnostic view")
    corpus_hash = None
    if args.view == "fixed":
        manifest_raw = (ROOT / "Fixtures/gfm/fixed-profile-v1.json").read_bytes()
        corpus_hash = hashlib.sha256(manifest_raw).hexdigest()
        manifest = json.loads(manifest_raw)
        by_id = {case["example"]: case for case in fixtures}
        ids = manifest["published_examples"]
        if len(set(ids)) != len(ids) or any(i not in by_id for i in ids):
            p.error("invalid or duplicate published fixture identifiers in fixed corpus")
        fixtures = [dict(by_id[i], provenance="published GFM example") for i in ids]
        for item in manifest["interaction_examples"]:
            fixtures.append({"example": item["id"], "section": "project-authored interaction", "markdown": item["markdown"], "html": item["html"], "provenance": item["rationale"]})
        if len({case["example"] for case in fixtures}) != len(fixtures):
            p.error("duplicate fixed-corpus identifiers")
    if args.gfm_historical_extension_map and args.profile != "gfm":
        p.error("historical extension mapping is only available for gfm")
    corpus_total = len(fixtures)
    if args.example is not None:
        fixtures = [case for case in fixtures if str(case["example"]) == str(args.example)]
        if not fixtures:
            p.error("example identifier not found")
    if args.gfm_historical_extension_map or args.view == "published":
        source = ROOT / "Fixtures/gfm/cmark-gfm-0.29.0.gfm.0-spec.txt"
        evidence_by_case = map_evidence(fixtures, source.read_bytes())
        results = []
        for case, (flags, reason) in zip(fixtures, evidence_by_case):
            config_source = "exact historical source example"
            if flags is None and args.view == "published" and case["example"] in OVERRIDES:
                flags = OVERRIDES[case["example"]]
                config_source = "project provisional setting from published specification section"
            if flags is None:
                results.append({"id": case["example"], "section": case["section"], "markdown": case["markdown"], "expected": case["html"], "actual": None, "status": "skip", "reason": reason, "classification": "unclassified"})
            else:
                case_command = command + [arg for flag in flags for arg in ("-e", flag)]
                row = run([case], case_command, args.timeout)[0]
                row["extensions"] = flags
                row["configuration_evidence"] = config_source
                row["historical_mapping_note"] = reason
                row["command"] = case_command
                results.append(row)
    else:
        results = run(fixtures, command, args.timeout)
    if args.view == "fixed":
        for row, case in zip(results, fixtures):
            row["provenance"] = case["provenance"]
            row["command"] = command
            row["configuration_evidence"] = "same user-supplied command for every case"
    for row in results:
        if row["id"] in (279, 280, "interaction-tasklist-strikethrough-1") and row["actual"] is not None:
            comparison = compare_html_tokens(row["expected"], row["actual"])
            row["secondary_diagnostic"] = {"type": "html_token_comparison", "result": comparison,
                "limitations": "Diagnostic only: compares simple HTML tokens ignoring attribute order and void-element slash; it does not establish AST equivalence, browser behavior, or safety."}
            if row["status"] == "fail" and row.get("exit_code") == 0 and comparison == "equivalent_tokens":
                row["classification"] = "renderer_serialization_likely"
    # Provide an exact one-case command without overwriting the aggregate report.
    replay_prefix = list(sys.argv[:separator])
    if "--example" in replay_prefix:
        pos = replay_prefix.index("--example")
        del replay_prefix[pos:pos + 2]
    report_pos = replay_prefix.index("--report")
    replay_prefix[report_pos + 1] = args.report + ".case.json"
    for row in results:
        row["reproduce"] = shlex.join([sys.executable, *replay_prefix, "--example", str(row["id"]), "--", *command])
    passed = sum(r["status"] == "pass" for r in results)
    failed = sum(r["status"] == "fail" for r in results)
    skipped = sum(r["status"] == "skip" for r in results)
    limitations = []
    if args.profile == "gfm":
        limitations.append("Published HTML extraction has not been independently verified against the exact source of this page.")
    if args.view == "published":
        limitations.append("Per-example extension settings include provisional project choices and historical source labels, not a verified global GFM profile.")
    if args.view == "fixed":
        limitations.append("Selected exploratory subset with project-authored interaction cases; this is not the complete published corpus.")
    if args.example is not None:
        limitations.append("Only one fixture was selected.")
    report = {"profile": args.profile, "view": args.view, "specification": version,
              "scope_status": "incomplete" if limitations or skipped else "complete",
              "limitations": limitations, "fixed_corpus_sha256": corpus_hash,
              "corpus_total": corpus_total, "published_corpus_total": 677 if args.profile == "gfm" else 652,
              "qualification_eligible": False if args.profile == "gfm" else args.example is None,
              "fixture_url": url,
              "fixture_sha256": digest, "command": command, "timeout_seconds": args.timeout,
              "python_version": platform.python_version(), "platform": platform.platform(),
              "renderer_version": args.renderer_version,
              "reproduce": shlex.join(sys.argv),
              "total": len(results), "passed": passed, "failed": failed,
              "skipped": skipped, "results": results}
    path = pathlib.Path(args.report)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    lines = [f"View: {args.view}; scope: {report['scope_status']}", *[f"Limitation: {item}" for item in limitations], f"{report['specification']}: {passed}/{len(results)} passed; {report['failed']} failed; {skipped} skipped",
             f"Corpus total: {corpus_total}; published corpus total: {report['published_corpus_total']}", f"Command: {command!r}", f"Fixture SHA-256: {digest}", f"Reproduce: {report['reproduce']}", f"Renderer: {args.renderer_version}"]
    for row in results:
        if row["status"] != "pass":
            lines.extend([f"\nExample {row['id']} ({row['section']}): {row.get('reason', row.get('error', 'mismatch or process error'))}",
                          f"Input: {row['markdown']!r}", f"Expected: {row['expected']!r}",
                          f"Actual: {row['actual']!r}", f"Configuration: {row.get('configuration_evidence', 'user-supplied command')!r}", f"Extensions: {row.get('extensions')!r}", f"Provenance: {row.get('provenance', 'published example')!r}", f"Historical mapping note: {row.get('historical_mapping_note')!r}", f"Exit: {row.get('exit_code')!r}",
                          f"stderr: {row.get('stderr', '')!r}", f"stdout hex: {row.get('stdout_hex', '')}",
                          f"Case reproduction: {row['reproduce']}", f"Secondary diagnostic: {row.get('secondary_diagnostic')!r}", f"Classification: {row['classification']}"])
    path.with_suffix(".txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(lines[0])
    print(next(line for line in lines if " passed; " in line))
    return 1 if report["failed"] or skipped or (args.view == "published" and report["scope_status"] == "incomplete") else 0


if __name__ == "__main__":
    sys.exit(main())
