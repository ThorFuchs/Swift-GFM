#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Builds the pinned upstream cmark-gfm reference executable with git, CMake and a C compiler.
set -eu
revision=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["revision"])' "$(dirname -- "$0")/../Vendor/GitHubCMark/UPSTREAM_SHA256.json")
root=${1:-"$PWD/.references"}
mkdir -p "$root"
root=$(cd "$root" && pwd)
if [ ! -d "$root/cmark-gfm/.git" ]; then
    git init -q "$root/cmark-gfm"
    git -C "$root/cmark-gfm" remote add origin https://github.com/github/cmark-gfm.git
fi
git -C "$root/cmark-gfm" fetch --depth 1 origin "$revision"
git -C "$root/cmark-gfm" checkout --detach "$revision"
test "$(git -C "$root/cmark-gfm" rev-parse HEAD)" = "$revision"
cmake -S "$root/cmark-gfm" -B "$root/cmark-gfm-build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$root/cmark-gfm-build" --parallel
printf 'Reference executable: %s\n' "$root/cmark-gfm-build/src/cmark-gfm"
