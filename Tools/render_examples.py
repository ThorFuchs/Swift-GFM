#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Render the gallery with the CLI; optionally verify HTML or make screenshots."""
import argparse
import html
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / "Examples"
EXTENSIONS = ("table", "strikethrough", "autolink", "tagfilter", "tasklist")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path, help="path to the built swift-gfm executable")
    parser.add_argument("--check", action="store_true", help="compare against committed HTML without writing")
    parser.add_argument("--chrome", type=Path, help="also generate screenshots with this Chrome executable")
    args = parser.parse_args()
    if args.check and args.chrome:
        parser.error("--check and --chrome cannot be used together")
    binary = args.binary.resolve()
    sources = sorted((EXAMPLES / "Markdown").glob("*.md"))
    if not sources:
        parser.error("no Markdown examples found")
    failed = False
    for source in sources:
        flags = [flag for extension in EXTENSIONS for flag in ("-e", extension)]
        if source.name == "08-footnotes.md":
            flags += ["-e", "footnotes"]
        result = subprocess.run([str(binary), "html", *flags, str(source)], check=True, capture_output=True).stdout
        output = EXAMPLES / "HTML" / (source.stem + ".html")
        if args.check:
            if not output.is_file() or output.read_bytes() != result:
                print(f"HTML differs or is missing: {output.relative_to(ROOT)}")
                failed = True
        else:
            output.write_bytes(result)
            if args.chrome:
                with tempfile.TemporaryDirectory(prefix="swift-gfm-gallery-") as tmp:
                    temp = Path(tmp)
                    css = (EXAMPLES / "preview.css").read_text(encoding="utf-8")
                    page = temp / "preview.html"
                    page.write_text(
                        '<!doctype html><html lang="en"><meta charset="utf-8">'
                        f'<style>{css}</style><div class="frame"><div class="label">SwiftGFM · '
                        f'{html.escape(source.stem[3:].replace("-", " "))}</div>'
                        f'{result.decode("utf-8")}</div></html>', encoding="utf-8")
                    subprocess.run([
                        str(args.chrome.resolve()), "--headless", "--disable-gpu", "--hide-scrollbars",
                        "--force-device-scale-factor=1", "--window-size=800,420",
                        f"--user-data-dir={temp / 'profile'}",
                        f"--screenshot={EXAMPLES / 'Images' / (source.stem + '.png')}", page.as_uri(),
                    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"{'Checked' if args.check else 'Rendered'} {source.relative_to(ROOT)}")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
