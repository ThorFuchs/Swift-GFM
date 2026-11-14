#!/bin/sh
# Build DocC without a package plugin or external documentation dependency.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=${1:-"$root/.build/docc-build"}
output=${2:-"$root/.build/SwiftGFM.doccarchive"}
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
docc convert Sources/SwiftGFM/SwiftGFM.docc --additional-symbol-graph-dir "$temp" \
  --fallback-display-name SwiftGFM --fallback-bundle-identifier org.swiftgfm.documentation \
  --fallback-bundle-version 0.1.0 --output-path "$output" --warnings-as-errors
printf 'Documentation archive: %s\n' "$output"
