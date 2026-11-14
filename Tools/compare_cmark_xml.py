#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare syntax-tree XML for failing CommonMark HTML examples (experimental)."""
import argparse
import json
import pathlib
import subprocess
import xml.etree.ElementTree as ET

LITERALS = {"text", "code", "code_block", "html_inline", "html_block", "custom_inline", "custom_block"}

def structure(element):
    tag = element.tag.rsplit("}", 1)[-1]
    attributes = {key: value for key, value in element.attrib.items() if key != "sourcepos"}
    text = element.text if tag in LITERALS else None
    return (tag, attributes, text, tuple(structure(child) for child in element))

def positions(element):
    return [(item.tag.rsplit("}", 1)[-1], item.attrib.get("sourcepos")) for item in element.iter()]

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--html-report", required=True)
    p.add_argument("--reference", required=True, help="pinned cmark 0.31.2 executable")
    p.add_argument("--probe", required=True, help="cmark-probe executable")
    p.add_argument("--report", required=True)
    args = p.parse_args()
    html = json.loads(pathlib.Path(args.html_report).read_text())
    if html.get("profile") != "commonmark":
        p.error("requires a CommonMark HTML report")
    rows = []
    for item in html["results"]:
        if item["status"] != "fail":
            continue
        commands = {"reference": [args.reference, "--to", "xml", "--sourcepos"], "probe": [args.probe, "xml-commonmark"]}
        row = {"id": item["id"], "markdown": item["markdown"], "runs": {}}
        parsed = {}
        for label, command in commands.items():
            try:
                result = subprocess.run(command, input=item["markdown"].encode(), capture_output=True, timeout=10)
                xml = result.stdout.decode("utf-8")
                row["runs"][label] = {"command": command, "returncode": result.returncode, "xml": xml, "stderr": result.stderr.decode("utf-8", errors="replace")}
                if result.returncode == 0:
                    parsed[label] = ET.fromstring(xml)
            except (OSError, subprocess.TimeoutExpired, UnicodeError, ET.ParseError) as error:
                row["runs"].setdefault(label, {})["error"] = str(error)
        if len(parsed) == 2:
            row["same_tree_ignoring_sourcepos"] = structure(parsed["reference"]) == structure(parsed["probe"])
            row["same_node_positions"] = positions(parsed["reference"]) == positions(parsed["probe"])
        rows.append(row)
    report = {"basis": args.html_report, "fixture_sha256": html.get("fixture_sha256"),
              "note": "Compares rendered XML trees, ignoring sourcepos only in the structural comparison. This is not a complete AST equivalence or source-range validation.", "results": rows}
    target = pathlib.Path(args.report)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, ensure_ascii=True, indent=2) + "\n")
    print(f"{len(rows)} failing HTML cases: {sum(r.get('same_tree_ignoring_sourcepos', False) for r in rows)} same XML structure, {sum(r.get('same_node_positions', False) for r in rows)} same node-position sequences")
    return 0 if all("same_tree_ignoring_sourcepos" in row for row in rows) else 1

if __name__ == "__main__":
    raise SystemExit(main())
