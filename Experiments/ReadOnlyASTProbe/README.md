# Read-only AST experiment

This is an isolated proof of concept, not a public SwiftGFM API. It builds an
immutable `Sendable` generic element tree from ordinary cmark XML and walks it
in a detached task. It deliberately rejects inputs with attribute whitespace
that XML would normalize and rejects XML parsers cannot read. It has not been
qualified over the fixture corpus and does not establish a faithful production
mapping, source-position semantics, or support for every extension node.

On a Linux checkout with the local Swift 6.4.2 toolchain and built CLI:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/swift-gfm-clang-cache \
  .toolchains/swift-6.4.2/usr/bin/swiftc -swift-version 6 -parse-as-library \
  Experiments/ReadOnlyASTProbe/main.swift -o /tmp/swift-gfm-read-only-ast-probe
printf 'Hello *Swift*!\n' | /tmp/swift-gfm-prod-build/debug/swift-gfm xml |
  /tmp/swift-gfm-read-only-ast-probe
```

Do not use this prototype to process untrusted XML or as a replacement for a
complete, tested conversion from the pinned cmark backend.
