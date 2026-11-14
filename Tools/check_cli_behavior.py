#!/usr/bin/env python3
"""Exercise the standalone CLI's input, output, and error contract."""
import argparse
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    args = parser.parse_args()
    # name, arguments, input, expected status, expected stdout, stderr fragment
    cases = [
        ("help", ["--help"], b"", 0, None, b""),
        ("version", ["--version"], b"", 0, b"cmark-gfm 0.29.0.gfm.13 (27d942c8b0a62d192f616e5bf3578f4b6a89e180)\n", b""),
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
