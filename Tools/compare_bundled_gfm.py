#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare Swift Markdown and cmark-gfm on a pinned upstream source suite."""
import argparse
import hashlib
import io
import json
import pathlib
import platform
import re
import shlex
import sys
from conformance import ROOT, run

SOURCES = {
    "historical": ("cmark-gfm-0.29.0.gfm.0-spec.txt", "7cea1221ffba48559d8748c8510d3c5bda40487a13667b80e77c14a1505b9821", "b8eb2e00de094999f978e9cb02b1a78d810812d3"),
    "current": ("cmark-gfm-0.29.0.gfm.13-spec.txt", "7d8e5814befec287ac116786d81ff14e0adc9b13295b4494649e995408fd871c", "27d942c8b0a62d192f616e5bf3578f4b6a89e180"),
}
FENCE = "`" * 32


def extract(raw):
    """Match upstream get_tests, but retain examples marked disabled."""
    state = 0
    section, flags = "", []
    markdown, html, cases = [], [], []
    start_line = 0
    for line_number, line in enumerate(io.StringIO(raw.decode("utf-8"), newline="\n"), 1):
        stripped = line.strip()
        if state == 0 and stripped.startswith(FENCE + " example"):
            flags = stripped[len(FENCE + " example"):].split()
            markdown, html, state, start_line = [], [], 1, line_number
        elif state and stripped == FENCE:
            if state != 2:
                raise ValueError(f"missing separator at line {line_number}")
            cases.append({"example": len(cases) + 1, "section": section, "flags": flags,
                "markdown": "".join(markdown).replace("→", "\t"),
                "html": "".join(html).replace("→", "\t"),
                "start_line": start_line, "end_line": line_number})
            state = 0
        elif state == 1 and stripped == ".":
            state = 2
        elif state == 1:
            markdown.append(line)
        elif state == 2:
            html.append(line)
        elif state == 0 and re.match(r"#+ ", line):
            section = re.sub(r"#+ ", "", line).strip()
    if state:
        raise ValueError("unterminated example")
    return cases


def counts(rows, key):
    return {status: sum(row[key]["status"] == status for row in rows) for status in ("pass", "fail", "skip")}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("suite", choices=SOURCES)
    p.add_argument("--swift-markdown", required=True, help="markdown-probe executable; invokes its html mode")
    p.add_argument("--reference", required=True, help="cmark-gfm executable from the selected pinned revision")
    p.add_argument("--report", required=True)
    args = p.parse_args()
    filename, digest, revision = SOURCES[args.suite]
    raw = (ROOT / "Fixtures/gfm" / filename).read_bytes()
    if hashlib.sha256(raw).hexdigest() != digest:
        p.error("upstream fixture checksum mismatch")
    cases = extract(raw)
    rows = []
    for case in cases:
        disabled = "disabled" in case["flags"]
        swift_cmd = [args.swift_markdown, "html"]
        swift = run([case], swift_cmd, 10)[0]
        swift["command"] = swift_cmd
        if disabled:
            reference = {"status": "skip", "reason": "upstream source marks example disabled"}
        else:
            ref_cmd = [args.reference, "--unsafe"] + [arg for flag in case["flags"] for arg in ("-e", flag)]
            reference = run([case], ref_cmd, 10)[0]
            reference["command"] = ref_cmd
        rows.append({"id": case["example"], "section": case["section"],
                     "lines": [case["start_line"], case["end_line"]],
                     "input": case["markdown"], "expected": case["html"],
                     "upstream_flags": case["flags"], "upstream_enabled": not disabled,
                     "swift_markdown": swift, "reference": reference})
    enabled = [row for row in rows if row["upstream_enabled"]]
    disabled = [row for row in rows if not row["upstream_enabled"]]
    report = {
        "suite": args.suite, "upstream_spec_revision": revision,
        "upstream_spec_url": f"https://github.com/github/cmark-gfm/blob/{revision}/test/spec.txt",
        "fixture_sha256": digest, "swift_markdown_revision": "ea1d88be47afe8a731b3971d7b3fb7a3a6db1a5a",
        "swift_cmark_revision": "437611671145d47e6d9679761b8a5987766f4ae5",
        "swift_configuration": "Document(parsing:options:.disableSmartOpts) and HTMLFormatter defaults; parser always attaches table, strikethrough and tasklist; it does not attach autolink or tagfilter.",
        "reference_configuration": "cmark-gfm --unsafe with per-example source extension flags. Disabled examples are not run against reference.",
        "comparison": "Raw UTF-8 output bytes; no normalization. Upstream test runner normalizes CRLF even with --no-normalize.",
        "limitation": "Swift Markdown cannot select the reference's per-example extensions through its public parser options; this compares fixed behavior with reference examples and is not a matched-configuration assessment of each case.",
        "renderer_revision_labels_are_not_executable_verification": True,
        "swift_binary_sha256": hashlib.sha256(pathlib.Path(args.swift_markdown).read_bytes()).hexdigest(),
        "reference_binary_sha256": hashlib.sha256(pathlib.Path(args.reference).read_bytes()).hexdigest(),
        "python_version": platform.python_version(), "platform": platform.platform(),
        "reproduce": shlex.join([sys.executable, *sys.argv]),
        "total_examples": len(rows), "enabled_examples": len(enabled), "disabled_examples": len(disabled),
        "enabled_swift": counts(enabled, "swift_markdown"), "enabled_reference": counts(enabled, "reference"),
        "disabled_swift": counts(disabled, "swift_markdown"), "results": rows,
    }
    path = pathlib.Path(args.report)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    lines = [f"Upstream suite: {args.suite} at {revision}", f"Enabled: {len(enabled)}, disabled: {len(disabled)}",
             f"Swift enabled: {report['enabled_swift']}", f"Reference enabled: {report['enabled_reference']}",
             f"Swift disabled (supplementary): {report['disabled_swift']}", report["limitation"],
             f"Reproduce: {report['reproduce']}"]
    for row in rows:
        if row["swift_markdown"]["status"] != "pass" or (row["upstream_enabled"] and row["reference"]["status"] != "pass"):
            lines.extend([f"\nExample {row['id']} ({row['section']}), source lines {row['lines']}, flags {row['upstream_flags']!r}",
                          f"Markdown: {row['input']!r}", f"Expected: {row['expected']!r}",
                          f"Swift status: {row['swift_markdown']['status']}; output: {row['swift_markdown']['actual']!r}",
                          f"Swift stderr: {row['swift_markdown'].get('stderr', '')!r}; error: {row['swift_markdown'].get('error', '')!r}",
                          f"Reference status: {row['reference']['status']}; output: {row['reference'].get('actual')!r}",
                          f"Reference stderr: {row['reference'].get('stderr', '')!r}; error: {row['reference'].get('error', '')!r}"])
    path.with_suffix(".txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines[:5]))
    return 1 if report["enabled_swift"]["fail"] or report["enabled_reference"]["fail"] else 0

if __name__ == "__main__":
    sys.exit(main())
