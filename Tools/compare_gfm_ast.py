#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare partial Swift Markdown and cmark-gfm AST projections for HTML failures."""
import argparse
from collections import Counter
import difflib
import hashlib
import json
import pathlib
import platform
import shlex
import subprocess
import sys
import xml.etree.ElementTree as ET

KINDS = {"document", "paragraph", "block_quote", "list", "item", "heading", "thematic_break", "code_block", "html_block", "link", "image", "text", "code", "html_inline", "softbreak", "linebreak", "emph", "strong", "strikethrough"}
LITERALS = {"text", "code", "code_block", "html_block", "html_inline"}
OMITTED_GROUPS = {"same_html5_fragment_tree", "structural_layout_whitespace_only"}


def strip_empty_fields(node):
    if node["kind"] in ("link", "image"):
        for name in ("destination", "title"):
            if node["attributes"].get(name) == "":
                del node["attributes"][name]
    if node["kind"] == "code_block" and node["attributes"].get("info") == "":
        del node["attributes"]["info"]
    for child in node["children"]:
        strip_empty_fields(child)


def merge_text_children(node):
    children = []
    for child in node["children"]:
        merge_text_children(child)
        if children and child["kind"] == "text" and children[-1]["kind"] == "text" and set(child["attributes"]) == {"literal"} and set(children[-1]["attributes"]) == {"literal"}:
            children[-1]["attributes"]["literal"] += child["attributes"]["literal"]
        else:
            children.append(child)
    node["children"] = children


def swift_tree(node, unknown):
    kind = node["kind"]
    if kind not in KINDS:
        unknown.add("Swift:" + kind)
    result = {"kind": kind, "attributes": dict(node["attributes"]), "children": [swift_tree(child, unknown) for child in node["children"]]}
    return result


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


def reference_tree(element, unknown, lost):
    kind = element.tag.rsplit("}", 1)[-1]
    attrs = {}
    if kind == "tasklist":
        kind = "item"
        attrs["checkbox"] = "checked" if element.attrib.get("completed") == "true" else "unchecked"
    if kind not in KINDS:
        unknown.add("cmark:" + kind)
    if kind == "list":
        attrs["type"] = element.attrib.get("type", "")
        if attrs["type"] == "ordered":
            attrs["start"] = element.attrib.get("start", "1")
            if "delim" in element.attrib:
                lost.add("ordered-list delimiter is not included in Swift projection")
        if "tight" in element.attrib:
            lost.add("list tightness is not stored by the Swift Markdown list model")
    elif kind == "heading":
        attrs["level"] = element.attrib.get("level", "")
    elif kind in ("link", "image"):
        for key in ("destination", "title"):
            if element.attrib.get(key):
                attrs[key] = element.attrib[key]
    elif kind == "code_block":
        if element.attrib.get("info"):
            attrs["info"] = element.attrib["info"]
    if kind in LITERALS:
        attrs["literal"] = element.text or ""
    return {"kind": kind, "attributes": attrs, "children": [reference_tree(child, unknown, lost) for child in element]}


def command(cmd, source):
    p = subprocess.run(cmd, input=source.encode("utf-8"), capture_output=True, timeout=10)
    return {"command": cmd, "returncode": p.returncode, "stdout": p.stdout.decode("utf-8"), "stderr": p.stderr.decode("utf-8", errors="backslashreplace")}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--clusters", required=True)
    p.add_argument("--paired", required=True)
    p.add_argument("--swift-markdown", required=True)
    p.add_argument("--reference", required=True)
    p.add_argument("--output", required=True)
    args = p.parse_args()
    cluster_bytes = pathlib.Path(args.clusters).read_bytes()
    pair_bytes = pathlib.Path(args.paired).read_bytes()
    clusters, paired = json.loads(cluster_bytes), json.loads(pair_bytes)
    if clusters["source_report_sha256"] != hashlib.sha256(pair_bytes).hexdigest():
        p.error("cluster report does not match paired report")
    if clusters["spec_revision"] != paired["upstream_spec_revision"]:
        p.error("mismatched source revision")
    swift_sha = hashlib.sha256(pathlib.Path(args.swift_markdown).read_bytes()).hexdigest()
    reference_sha = hashlib.sha256(pathlib.Path(args.reference).read_bytes()).hexdigest()
    if reference_sha != paired["reference_binary_sha256"]:
        p.error("reference binary does not match the paired HTML run")
    # AST projection support may have required rebuilding the Swift probe. Re-run
    # its html mode for every input and require exact agreement with paired data.
    by_id = {case["id"]: case for case in paired["results"]}
    candidates = [case for case in clusters["results"] if case["analysis"]["primary"] not in OMITTED_GROUPS]
    results = []
    for case in candidates:
        original = by_id[case["id"]]
        row = {"id": case["id"], "section": case["section"], "html_cluster": case["analysis"]["primary"],
               "upstream_flags": case["upstream_flags"], "input": case["markdown"],
               "expected_html": case["expected"], "actual_html": case["actual"],
               "unrepresented_fields": [], "unknown_node_kinds": []}
        flags = [f for f in case["upstream_flags"] if f != "disabled"]
        ref_cmd = [args.reference, "--to", "xml"] + [arg for flag in flags for arg in ("-e", flag)]
        try:
            html_run = command([args.swift_markdown, "html"], case["markdown"])
            if html_run["returncode"] != 0 or html_run["stdout"] != case["actual"]:
                row["status"] = "inconclusive"
                row["reason"] = "current Swift probe HTML differs from paired report or failed"
                row["html_recheck"] = html_run
                results.append(row)
                continue
            swift_run = command([args.swift_markdown, "ast-json"], case["markdown"])
            ref_run = command(ref_cmd, case["markdown"])
            row["swift_run"] = swift_run
            row["reference_run"] = ref_run
            if swift_run["returncode"] or ref_run["returncode"]:
                raise ValueError("AST command failed")
            swift_raw = json.loads(swift_run["stdout"])
            reference_raw = ET.fromstring(preserve_xml_attribute_whitespace(ref_run["stdout"]))
            unknown, lost = set(), set()
            swift = swift_tree(swift_raw, unknown)
            reference = reference_tree(reference_raw, unknown, lost)
            for tree in (swift, reference):
                strip_empty_fields(tree)
                merge_text_children(tree)
            row["swift_projection"] = swift
            row["reference_projection"] = reference
            row["unrepresented_fields"] = sorted(lost)
            row["unknown_node_kinds"] = sorted(unknown)
            if unknown:
                row["status"] = "inconclusive"
                row["reason"] = "one or more AST node types lack a validated projection"
            elif swift == reference:
                row["status"] = "projection_match"
            else:
                row["status"] = "projection_difference"
                expected = json.dumps(reference, indent=2, ensure_ascii=True, sort_keys=True).splitlines(keepends=True)
                actual = json.dumps(swift, indent=2, ensure_ascii=True, sort_keys=True).splitlines(keepends=True)
                row["projection_diff"] = "".join(difflib.unified_diff(expected, actual, fromfile="cmark projection", tofile="Swift projection"))
        except (OSError, UnicodeError, ValueError, KeyError, TypeError, ET.ParseError, subprocess.TimeoutExpired) as error:
            row["status"] = "inconclusive"
            row["reason"] = str(error)
        if "tagfilter" in flags:
            row["render_only_extension_note"] = "Tag filtering affects HTML rendering; an AST match does not mean the filter was applied."
        results.append(row)
    counts = Counter(row["status"] for row in results)
    report = {"fixture_sha256": paired["fixture_sha256"], "source_revision": paired["upstream_spec_revision"],
              "swift_markdown_revision": paired["swift_markdown_revision"], "swift_cmark_revision": paired["swift_cmark_revision"],
              "source_report_sha256": hashlib.sha256(pair_bytes).hexdigest(), "clusters_sha256": hashlib.sha256(cluster_bytes).hexdigest(),
              "swift_binary_sha256": swift_sha, "reference_binary_sha256": reference_sha,
              "python_version": platform.python_version(), "reproduce": shlex.join([sys.executable, *sys.argv]),
              "skipped_html_clusters": sorted(OMITTED_GROUPS), "selected_count": len(results), "counts": dict(counts),
              "limitations": ["AST projection equality is not proof of correctness or complete AST equivalence.", "Swift and reference use different parser extension configurations; reference follows each fixture's flags.", "List tightness and ordered-list delimiter are omitted from projection; cases list applicable omitted fields.", "Empty link/image values are normalized to absent and adjacent text nodes are merged; source positions and original syntax are excluded.", "Literal tabs and newlines in cmark XML attributes are encoded before XML parsing to preserve the original values; this conversion applies only to the reference renderer output used here.", "Unknown node kinds and process/XML errors are inconclusive; raw outputs are retained.", "Reference implementation is not normative evidence independent of the fixture and may contain its own bugs.", "Tag filtering is a render policy and cannot be verified by this tree comparison."],
              "results": results}
    target = pathlib.Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    md = ["# Swift Markdown versus cmark-gfm AST projections", "", f"Cases analyzed: {len(results)}", f"Counts: {dict(counts)}", "", "Projection matches are partial only. See limitations and JSON for complete projections and original HTML.", "", "## Limitations", ""] + ["- " + x for x in report["limitations"]]
    for row in results:
        md.extend(["", f"## Example {row['id']} — {row['section']}", "", f"Status: `{row['status']}`. HTML cluster: `{row['html_cluster']}`. Source extension flags: `{row['upstream_flags']}`.", "", f"Unrepresented: {row['unrepresented_fields']!r}. Unknown kinds: {row['unknown_node_kinds']!r}."])
        if row.get("reason"): md.extend(["", "Reason: " + row["reason"]])
        if row.get("render_only_extension_note"): md.extend(["", row["render_only_extension_note"]])
        if row.get("projection_diff"): md.extend(["", "```diff", row["projection_diff"].rstrip("\n"), "```"])
    target.with_suffix(".md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"Selected {len(results)} cases: " + ", ".join(f"{key}={value}" for key, value in sorted(counts.items())))
    return 1 if counts.get("inconclusive", 0) or counts.get("projection_difference", 0) else 0

if __name__ == "__main__":
    sys.exit(main())
