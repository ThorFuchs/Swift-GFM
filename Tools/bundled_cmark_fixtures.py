# SPDX-License-Identifier: Apache-2.0

"""Provenance for the unmodified test resources from the pinned C backend."""
import io
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
VENDOR = ROOT / "Vendor/GitHubCMark"
# The vendored source manifest is the single source of truth for the pinned revision.
REVISION = json.loads((VENDOR / "UPSTREAM_SHA256.json").read_text(encoding="utf-8"))["revision"]
VERSION = re.search(r'CMARK_GFM_VERSION_STRING "([^"]+)"',
                    (VENDOR / "generated/cmark-gfm_version.h").read_text(encoding="utf-8")).group(1)
DIRECTORY = ROOT / "Tests/SwiftGFMTests/Fixtures/cmark-gfm"
SOURCES = {
    "spec": ("7d8e5814befec287ac116786d81ff14e0adc9b13295b4494649e995408fd871c", 672),
    "extensions": ("a2a45e98be9fca95f564f927265a0f63beea6cae5369d1cf4bde44caa51b2a3a", 30),
    "regression": ("0920d7e8134d5e4ec3693f3f52d904b42de45e23a66c29f54fe714dc54213fd9", 26),
    "smart_punct": ("b1dcfb0e0b6f314cf087edc06f47d9271849da539acfbfac0b9d7b16f10139c9", 16),
    "extensions-full-info-string": ("dec5fc65880d74f97d5181e0b75466fbe12662cda8383d8b51fd78e06191092f", 4),
    "extensions-table-prefer-style-attributes": ("3d902a4a1ce48df5dd7910647602fbae4535d8bac6700e918280fe1d928a4cee", 1),
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

