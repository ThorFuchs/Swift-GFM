#!/usr/bin/env python3
"""Cluster strict HTML differences without changing conformance results."""
import argparse
from collections import Counter, defaultdict
import difflib
import hashlib
import html5lib
import json
import pathlib
import platform
import re
import shlex
import sys

# Remove only newline-containing, whitespace-only text between block children in
# these structural containers. Never normalize text in inline/code contexts.
STRUCTURAL = {"DOCUMENT_FRAGMENT", "ul", "ol", "li", "blockquote", "table", "thead", "tbody", "tfoot", "tr", "div", "section", "article"}
BLOCK = {"p", "ul", "ol", "li", "blockquote", "pre", "table", "thead", "tbody", "tfoot", "tr", "td", "th", "div", "section", "article", "hr", "h1", "h2", "h3", "h4", "h5", "h6"}
SPECIAL = {"pre", "code", "script", "style", "textarea"}
SPACE = re.compile(r"[\t\n\f\r ]+\Z")


def tag_name(tag):
    if not isinstance(tag, str):
        return "#comment" if "Comment" in str(tag) else str(tag)
    return tag.rsplit("}", 1)[-1]


def parse(raw):
    parser = html5lib.HTMLParser(tree=html5lib.getTreeBuilder("etree"), namespaceHTMLElements=False)
    tree = parser.parseFragment(raw)
    return tree, [str(error) for error in parser.errors]


def layout_whitespace(parent, value, children, protected):
    return bool(not protected and tag_name(parent.tag) in STRUCTURAL and value and "\n" in value
                and SPACE.fullmatch(value) and all(tag_name(child.tag) in BLOCK for child in children))


def canonical(element, ignore_layout=False, protected=False):
    tag = tag_name(element.tag)
    protected = protected or tag in SPECIAL
    children = list(element)
    text = element.text
    if ignore_layout and layout_whitespace(element, text, children, protected):
        text = None
    entries = []
    for child in children:
        tail = child.tail
        if ignore_layout and layout_whitespace(element, tail, children, protected):
            tail = None
        entries.append((canonical(child, ignore_layout, protected), tail))
    attrs = tuple(sorted((str(k), v) for k, v in element.attrib.items()))
    return (tag, attrs, text, tuple(entries))


def full_text(node):
    return "".join(node.itertext())


def markers(tree):
    nodes = list(tree.iter())
    tags = Counter(tag_name(node.tag) for node in nodes)
    links = Counter((node.attrib.get("href"), node.attrib.get("title"), full_text(node))
                    for node in nodes if tag_name(node.tag) == "a")
    images = Counter((node.attrib.get("src"), node.attrib.get("alt"), node.attrib.get("title"))
                     for node in nodes if tag_name(node.tag) == "img")
    attributes = Counter((tag_name(node.tag), str(key), str(value)) for node in nodes for key, value in node.attrib.items())
    return tags, links, images, attributes


def cluster(expected, actual):
    exp, exp_errors = parse(expected)
    got, got_errors = parse(actual)
    raw_equal = canonical(exp) == canonical(got)
    relaxed_equal = canonical(exp, True) == canonical(got, True)
    etags, elinks, eimages, eattrs = markers(exp)
    atags, alinks, aimages, aattrs = markers(got)
    labels = []
    if elinks != alinks:
        labels.append("link_or_link_attribute_changed")
    if Counter(x[0] for x in elinks.elements()) != Counter(x[0] for x in alinks.elements()):
        labels.append("link_destinations_or_counts_differ")
    if Counter(x[1] for x in elinks.elements()) != Counter(x[1] for x in alinks.elements()):
        labels.append("link_titles_or_counts_differ")
    if eimages != aimages:
        labels.append("image_or_image_attribute_changed")
    if Counter(x[1] for x in eimages.elements()) != Counter(x[1] for x in aimages.elements()):
        labels.append("image_alt_or_counts_differ")
    if Counter(x[2] for x in eimages.elements()) != Counter(x[2] for x in aimages.elements()):
        labels.append("image_title_or_counts_differ")
    if etags["li"] and atags["li"] and atags["p"] > etags["p"]:
        labels.append("additional_paragraph_elements_with_list")
    if atags["strong"] < etags["strong"]:
        labels.append("fewer_strong_elements")
    if etags != atags:
        labels.append("element_inventory_changed")
    if eattrs != aattrs:
        labels.append("attribute_inventory_changed")
    if full_text(exp) != full_text(got):
        labels.append("dom_text_changed_including_whitespace")
    if raw_equal:
        primary = "same_html5_fragment_tree"
    elif relaxed_equal:
        primary = "structural_layout_whitespace_only"
    elif elinks != alinks:
        primary = "link_or_link_attribute_changed"
    elif eimages != aimages:
        primary = "image_or_image_attribute_changed"
    elif etags != atags:
        primary = "element_inventory_changed"
    elif eattrs != aattrs:
        primary = "other_attribute_inventory_changed"
    elif full_text(exp) != full_text(got):
        primary = "dom_text_changed"
    else:
        primary = "other_tree_difference"
    return {"primary": primary, "labels": labels, "same_html5_fragment_tree": raw_equal,
            "same_after_structural_whitespace_rule": relaxed_equal,
            "expected_html5_parse_errors": exp_errors, "actual_html5_parse_errors": got_errors,
            "expected_links": sorted([list(item) for item in elinks.elements()], key=repr),
            "actual_links": sorted([list(item) for item in alinks.elements()], key=repr),
            "expected_images": sorted([list(item) for item in eimages.elements()], key=repr),
            "actual_images": sorted([list(item) for item in aimages.elements()], key=repr),
            "expected_element_counts": dict(etags), "actual_element_counts": dict(atags)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", help="compare_bundled_gfm.py JSON output")
    parser.add_argument("--output", required=True, help="JSON output; a Markdown companion is also written")
    args = parser.parse_args()
    source = pathlib.Path(args.report).read_bytes()
    report = json.loads(source)
    results = []
    for row in report["results"]:
        if not row["upstream_enabled"] or row["swift_markdown"]["status"] != "fail":
            continue
        actual = row["swift_markdown"]["actual"]
        expected = row["expected"]
        if actual is None or row["swift_markdown"].get("exit_code") != 0:
            analysis = {"primary": "execution_error_or_non_utf8", "labels": [], "expected_html5_parse_errors": [], "actual_html5_parse_errors": []}
        else:
            analysis = cluster(expected, actual)
        diff = "".join(difflib.unified_diff(expected.splitlines(keepends=True), actual.splitlines(keepends=True) if actual is not None else [], fromfile="expected", tofile="Swift Markdown"))
        results.append({"id": row["id"], "section": row["section"], "source_lines": row["lines"],
                        "upstream_flags": row["upstream_flags"], "markdown": row["input"],
                        "expected": expected, "actual": actual, "analysis": analysis, "unified_diff": diff,
                        "execution_error": row["swift_markdown"].get("error"), "stderr": row["swift_markdown"].get("stderr")})
    primary = Counter(item["analysis"]["primary"] for item in results)
    tags = Counter(label for item in results for label in item["analysis"]["labels"])
    parse_errors = sum(bool(item["analysis"]["expected_html5_parse_errors"] or item["analysis"]["actual_html5_parse_errors"]) for item in results)
    output = {"suite": report["suite"], "spec_revision": report["upstream_spec_revision"],
              "fixture_sha256": report["fixture_sha256"], "source_report_sha256": hashlib.sha256(source).hexdigest(),
              "swift_markdown_revision": report["swift_markdown_revision"], "swift_binary_sha256": report["swift_binary_sha256"],
              "strict_failing_enabled_cases": len(results), "primary_counts": dict(primary), "overlapping_signal_counts": dict(tags),
              "cases_with_html5_parse_errors": parse_errors, "html5lib_version": html5lib.__version__, "python_version": platform.python_version(),
              "reproduce": shlex.join([sys.executable, *sys.argv]),
              "limitations": ["Supplementary analysis only: every case remains a strict byte failure.", "HTML5 parsed-tree equality does not prove equivalence under every browser context, CSS, scripts, accessibility, security or Markdown AST.", "Structural whitespace removal is a narrow heuristic and may change output under some CSS or contexts.", "HTML5 parse errors indicate error recovery; classifications require manual review.", "Swift Markdown and the C reference use different extension configurations; upstream per-example flags remain visible.", "Link, image, element, attribute and text signals overlap; primary clusters use a deterministic priority and are not proven root causes."], "results": results}
    destination = pathlib.Path(args.output)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(output, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    groups = defaultdict(list)
    for item in results:
        groups[item["analysis"]["primary"]].append(item)
    md = [f"# GFM bundled failure analysis: {report['suite']}", "", f"Strict failures: {len(results)}. All remain failures.",
          f"HTML5 parser: html5lib {html5lib.__version__}. Cases with HTML5 parse errors: {parse_errors}.", "",
          "Primary clusters are mutually exclusive and ordered by diagnostic priority; signal counts can overlap. See the JSON for full inputs and exact strings.", "", "| Primary cluster | Cases | Example IDs |", "| --- | ---: | --- |"]
    for name, group in groups.items():
        md.append(f"| `{name}` | {len(group)} | {', '.join(str(x['id']) for x in group[:12])}{' …' if len(group) > 12 else ''} |")
    md.extend(["", "## Limitations", ""] + [f"- {item}" for item in output["limitations"]] + ["", "## Case-by-case diffs", ""])
    for item in results:
        md.extend([f"### Example {item['id']} — {item['section']}", "", f"Primary: `{item['analysis']['primary']}`. Flags: `{item['upstream_flags']}`. Signals: `{item['analysis']['labels']}`.", "", "```diff", item['unified_diff'].rstrip("\n") or "(No line diff; consult exact strings and process diagnostics in JSON.)", "```", ""])
    destination.with_suffix(".md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"{report['suite']}: {len(results)} strict failures; HTML5 parse errors in {parse_errors} cases")
    for name, count in primary.most_common():
        print(f"{name}: {count}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
