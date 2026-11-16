#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Build DocC without a package plugin or external documentation dependency.
#   Tools/build-docc.sh [scratch-dir] [output] [hosting-base-path]
# With a hosting base path, the output is a static website for GitHub Pages.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=${1:-"$root/.build/docc-build"}
output=${2:-"$root/.build/SwiftGFM.doccarchive"}
base=${3:-}
mkdir -p "$scratch"
scratch=$(CDPATH= cd -- "$scratch" && pwd)
mkdir -p "$(dirname -- "$output")"
output="$(CDPATH= cd -- "$(dirname -- "$output")" && pwd)/$(basename -- "$output")"
cd "$root"
swift package --disable-sandbox --scratch-path "$scratch" dump-symbol-graph --skip-synthesized-members
symbol=$(find "$scratch" -type f -name SwiftGFM.symbols.json -print -quit)
test -n "$symbol"
python3 Tools/check_symbol_documentation.py "$symbol"
temp=$(mktemp -d "${TMPDIR:-/tmp}/swift-gfm-docc.XXXXXXXX")
trap 'rm -rf "$temp"' EXIT HUP INT TERM
cp "$symbol" "$temp/SwiftGFM.symbols.json"
set -- convert Sources/SwiftGFM/SwiftGFM.docc --additional-symbol-graph-dir "$temp" \
  --fallback-display-name SwiftGFM --fallback-bundle-identifier io.github.thorfuchs.swift-gfm \
  --fallback-bundle-version 1.0.0 --output-path "$output" --warnings-as-errors
if [ -n "$base" ]; then
  set -- "$@" --transform-for-static-hosting --hosting-base-path "$base"
fi
if command -v docc >/dev/null 2>&1; then docc "$@"; else xcrun docc "$@"; fi
printf 'Documentation archive: %s\n' "$output"
