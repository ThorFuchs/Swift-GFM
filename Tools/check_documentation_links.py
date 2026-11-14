#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check local Markdown link targets in the project's documentation."""
from pathlib import Path
import os
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
INLINE_LINK = re.compile(r"\[[^\]]+\]\((<[^>]+>|[^\s)]+)(?:\s+[^)]*)?\)")
REFERENCE_LINK = re.compile(r"^\s*\[[^\]]+\]:\s*(<[^>]+>|\S+)")
FENCE = re.compile(r"^\s*(`{3,}|~{3,})")


def links(text):
    """Yield inline and reference link destinations outside fenced code."""
    fence = None
    for line_number, line in enumerate(text.splitlines(), 1):
        match = FENCE.match(line)
        if match:
            marker = match.group(1)
            if fence is None:
                fence = marker
            elif marker[0] == fence[0] and len(marker) >= len(fence):
                fence = None
            continue
        if fence is not None:
            continue
        for match in INLINE_LINK.finditer(line):
            yield line_number, match.group(1).strip("<>")
        reference = REFERENCE_LINK.match(line)
        if reference:
            yield line_number, reference.group(1).strip("<>")


def documentation_files(root):
    def find(directory, *, all_markdown):
        for current, directories, names in os.walk(directory):
            directories[:] = [name for name in directories if name not in {".build", ".git", ".swiftpm"}]
            for name in names:
                if (all_markdown and name.endswith(".md")) or (not all_markdown and name == "README.md"):
                    yield Path(current) / name

    files = [path for path in (root / "README.md", root / "SECURITY.md") if path.exists()]
    for directory in ("Documentation", "Sources/SwiftGFM/SwiftGFM.docc"):
        files.extend(find(root / directory, all_markdown=True))
    for directory in ("Fixtures", "Tests/SwiftGFMTests/Fixtures", "Experiments"):
        files.extend(find(root / directory, all_markdown=False))
    return sorted(set(files))


def main():
    files = documentation_files(ROOT)
    failures = []
    for path in files:
        for line, destination in links(path.read_text(encoding="utf-8")):
            parsed = urlsplit(destination)
            if parsed.scheme or parsed.netloc or not parsed.path or parsed.path.startswith("/"):
                continue
            target = (path.parent / unquote(parsed.path)).resolve()
            if not target.exists():
                failures.append(f"{path.relative_to(ROOT)}:{line}: {destination}")
    if failures:
        print("Missing local Markdown link targets:")
        print("\n".join(failures))
    print(f"Checked local Markdown links in {len(files)} files; {len(failures)} missing targets")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
