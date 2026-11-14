#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare the Swift AST projection with independently rendered cmark XML."""
import argparse
import hashlib
import json
import pathlib
import platform
import subprocess
import sys
import xml.etree.ElementTree as ET

from bundled_cmark_fixtures import DIRECTORY, REVISION, SOURCES, extract

LITERALS = {"text", "code", "code_block", "html_inline", "html_block"}


def preserve_xml_attribute_whitespace(xml):
    """Recover cmark's literal attribute characters before XML normalization.

    cmark's XML renderer writes literal LF/CR/TAB in quoted attributes. An XML
    parser otherwise silently normalizes those to spaces. Character references
    retain the original codepoints. This is not general-purpose XML rewriting.
    """
    out = []
    in_tag = False
    quote = None
    replacements = {"\n": "&#10;", "\r": "&#13;", "\t": "&#9;"}
    for char in xml:
        if not in_tag:
            if char == "<": in_tag = True
            out.append(char)
        elif quote is not None:
            if char == quote:
                quote = None
                out.append(char)
            else:
                out.append(replacements.get(char, char))
        else:
            out.append(char)
            if char in ("'", '"'): quote = char
            elif char == ">": in_tag = False
    return "".join(out)



def xml_tree(element):
    kind = element.tag.rsplit("}", 1)[-1]
    attributes = {k: v for k, v in element.attrib.items() if k != "{http://www.w3.org/XML/1998/namespace}space"}
    result = {"kind": kind, "attributes": attributes, "children": [xml_tree(c) for c in element]}
    if kind in LITERALS:
        result["literal"] = element.text or ""
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", required=True)
    parser.add_argument("--reference", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--full-gfm", action="store_true", help="attach all five built-in GFM extensions to every example")
    args = parser.parse_args()
    digest, _ = SOURCES["spec"]
    revision = REVISION
    raw = (DIRECTORY / "spec.txt").read_bytes()
    if hashlib.sha256(raw).hexdigest() != digest:
        parser.error("fixture checksum mismatch")
    all_cases = extract(raw)
    cases = [dict(x) for x in all_cases if "disabled" not in x["flags"]]
    if args.full_gfm:
        for case in cases:
            case["flags"] = ["table", "strikethrough", "autolink", "tagfilter", "tasklist"]
    input_data = "".join(json.dumps({"markdown": x["markdown"], "extensions": x["flags"]}) + "\n" for x in cases)
    probe = subprocess.run([args.probe], input=input_data, text=True, capture_output=True, timeout=180)
    if probe.returncode:
        parser.error(f"probe exited {probe.returncode}: {probe.stderr}")
    lines = probe.stdout.splitlines()
    if len(lines) != len(cases):
        parser.error(f"probe returned {len(lines)} lines for {len(cases)} cases")
    rows = []
    for case, line in zip(cases, lines):
        response = json.loads(line)
        command = [args.reference, "--to", "xml", "--sourcepos"] + [v for flag in case["flags"] for v in ("-e", flag)]
        row = {"id": case["example"], "flags": case["flags"], "section": case["section"]}
        try:
            run = subprocess.run(command, input=case["markdown"], text=True, capture_output=True, timeout=10)
            if run.returncode:
                raise ValueError(f"reference exited {run.returncode}: {run.stderr}")
            expected = xml_tree(ET.fromstring(preserve_xml_attribute_whitespace(run.stdout)))
            actual = response.get("tree")
            row["match"] = actual == expected
            if not row["match"]:
                row.update({"markdown": case["markdown"], "expected": expected, "actual": actual, "error": response.get("error")})
        except (ValueError, ET.ParseError, subprocess.TimeoutExpired) as error:
            row.update({"match": False, "markdown": case["markdown"], "error": str(error)})
        rows.append(row)
    failures = [row for row in rows if not row["match"]]
    report = {"revision": revision, "fixture_sha256": digest, "full_gfm": args.full_gfm,
              "reference_sha256": hashlib.sha256(pathlib.Path(args.reference).read_bytes()).hexdigest(),
              "probe_sha256": hashlib.sha256(pathlib.Path(args.probe).read_bytes()).hexdigest(),
              "python": platform.python_version(),
              "comparison": "XML-representable node kinds, children, literals, attributes and source positions; attribute whitespace repaired before XML parsing. Extra C-only fields are not covered.",
              "total": len(rows), "passed": len(rows) - len(failures), "failed": len(failures),
              "upstream_disabled": [x["example"] for x in all_cases if "disabled" in x["flags"]],
              "results": rows}
    pathlib.Path(args.report).write_text(json.dumps(report, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print(f"AST XML projection: {report['passed']}/{report['total']} matched, {report['failed']} failed; upstream-disabled {report['upstream_disabled']}")
    for row in failures[:15]:
        print(f"  example {row['id']}: {row.get('error') or 'tree difference'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
