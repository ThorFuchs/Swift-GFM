# SPDX-License-Identifier: Apache-2.0

"""Map published examples to historical cmark-gfm source examples by exact content.

This is evidence for reference configuration, not proof that the historical
source is identical to the published specification.
"""
from collections import defaultdict
import hashlib

SHA256 = "7cea1221ffba48559d8748c8510d3c5bda40487a13667b80e77c14a1505b9821"
FENCE = "`" * 32


def source_examples(raw):
    if hashlib.sha256(raw).hexdigest() != SHA256:
        raise ValueError("historical GFM source checksum mismatch")
    state = 0
    markdown, html, flags = [], [], []
    examples = []
    for line in raw.decode("utf-8").splitlines(keepends=True):
        stripped = line.strip()
        if state == 0 and stripped.startswith(FENCE + " example"):
            flags = stripped[len(FENCE + " example"):].split()
            markdown, html, state = [], [], 1
        elif state and stripped == FENCE:
            if state != 2:
                raise ValueError("missing example separator")
            examples.append(("".join(markdown).replace("→", "\t"), "".join(html).replace("→", "\t"), tuple(flags)))
            state = 0
        elif state == 1 and stripped == ".":
            state = 2
        elif state == 1:
            markdown.append(line)
        elif state == 2:
            html.append(line)
    if state:
        raise ValueError("unterminated example")
    return examples


def map_evidence(cases, raw):
    mapping = defaultdict(set)
    for markdown, html, flags in source_examples(raw):
        mapping[(markdown, html)].add(flags)
    out = []
    for case in cases:
        flags = mapping[(case["markdown"], case["html"])]
        if not flags:
            out.append((None, "no exact input-and-output match in historical source"))
        elif len(flags) != 1:
            out.append((None, "historical matches have conflicting extension labels"))
        elif "disabled" in next(iter(flags)):
            out.append((None, "matching historical source example is explicitly disabled"))
        else:
            out.append((next(iter(flags)), None))
    return out


def map_examples(cases, raw):
    return [flags for flags, _ in map_evidence(cases, raw)]
