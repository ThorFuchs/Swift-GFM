#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Requires git, CMake and a C compiler. Builds the exact inspected revisions locally.
set -eu
root=${1:-"$PWD/.references"}
mkdir -p "$root"
root=$(cd "$root" && pwd)
build_one() {
    name=$1 url=$2 revision=$3
    if [ ! -d "$root/$name/.git" ]; then
        git init -q "$root/$name"
        git -C "$root/$name" remote add origin "$url"
    fi
    git -C "$root/$name" fetch --depth 1 origin "$revision"
    git -C "$root/$name" checkout --detach "$revision"
    test "$(git -C "$root/$name" rev-parse HEAD)" = "$revision"
    if [ "$name" = cmark-gfm-2019 ]; then
        cmake -S "$root/$name" -B "$root/$name-build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    else
        cmake -S "$root/$name" -B "$root/$name-build" -DCMAKE_BUILD_TYPE=Release
    fi
    cmake --build "$root/$name-build" --parallel
}
build_one cmark https://github.com/commonmark/cmark.git eec0eeba6d31189fd828314576494566d539b1e3
build_one cmark-gfm https://github.com/github/cmark-gfm.git 27d942c8b0a62d192f616e5bf3578f4b6a89e180
build_one cmark-gfm-2019 https://github.com/github/cmark-gfm.git b8eb2e00de094999f978e9cb02b1a78d810812d3
