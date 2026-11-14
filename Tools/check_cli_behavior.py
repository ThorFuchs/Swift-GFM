#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise the standalone CLI's input, output, and error contract."""
import argparse
import pathlib
import subprocess
import sys
import tempfile

from bundled_cmark_fixtures import REVISION, VERSION


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    args = parser.parse_args()
    directory = tempfile.TemporaryDirectory()
    first = pathlib.Path(directory.name) / "first.md"
    second = pathlib.Path(directory.name) / "second.md"
    first.write_bytes(b"# One\n")
    second.write_bytes(b"*two*\n")
    missing = str(pathlib.Path(directory.name) / "missing.md")
    # name, arguments, input, expected status, expected stdout, stderr fragment
    cases = [
        ("help", ["--help"], b"", 0, None, b""),
        ("version", ["--version"], b"", 0, f"cmark-gfm {VERSION} ({REVISION})\n".encode(), b""),
        ("default HTML", ["html"], b"Hello *Swift*!\n", 0, b"<p>Hello <em>Swift</em>!</p>\n", b""),
        ("empty source", ["html"], b"", 0, b"", b""),
        ("extension", ["html", "-e", "autolink"], b"www.example.com\n", 0, b'<p><a href="http://www.example.com">www.example.com</a></p>\n', b""),
        ("missing format", [], b"", 2, b"", b"usage:"),
        ("unknown format", ["bad"], b"", 2, b"", b"unknown output format"),
        ("missing extension", ["html", "-e"], b"", 2, b"", b"missing extension name"),
        ("unknown extension", ["html", "-e", "bad"], b"", 2, b"", b"unknown extension"),
        ("negative width", ["html", "--width", "-1"], b"", 2, b"", b"invalid width"),
        ("too large width", ["html", "--width", "2147483648"], b"", 2, b"", b"render failed"),
        ("unknown option", ["html", "--bad"], b"", 2, b"", b"unknown option"),
        ("invalid UTF-8", ["html"], b"bad\xff", 2, b"", b"input is not valid UTF-8"),
        ("short version", ["-V"], b"", 0, f"cmark-gfm {VERSION} ({REVISION})\n".encode(), b""),
        ("one file", ["html", str(first)], b"ignored\n", 0, b"<h1>One</h1>\n", b""),
        ("files in order", ["html", str(first), str(second)], b"", 0, b"<h1>One</h1>\n<p><em>two</em></p>\n", b""),
        ("file and stdin", ["html", str(second), "-"], b"three\n", 0, b"<p><em>two</em>\nthree</p>\n", b""),
        ("options after file", ["html", str(first), "--sourcepos"], b"", 0, b'<h1 data-sourcepos="1:1-1:5">One</h1>\n', b""),
        ("double dash", ["html", "--", str(first)], b"", 0, b"<h1>One</h1>\n", b""),
        ("missing file", ["html", missing], b"", 2, b"", b"cannot read file"),
    ]
    failures = 0
    for name, argv, data, status, stdout, stderr in cases:
        result = subprocess.run([args.binary, *argv], input=data, capture_output=True, timeout=10)
        passed = (result.returncode == status and (stdout is None or result.stdout == stdout)
                  and (name != "help" or b"usage:" in result.stdout)
                  and (not stderr or stderr in result.stderr) and (stderr or not result.stderr))
        if not passed:
            failures += 1
            print(f"FAIL {name}: status={result.returncode}, stdout={result.stdout!r}, stderr={result.stderr!r}")
    print(f"CLI behavior: {len(cases) - failures}/{len(cases)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
