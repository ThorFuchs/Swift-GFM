# Changelog

All notable changes to this project are documented here. The project follows
[Semantic Versioning](https://semver.org); see the
[versioning policy](README.md#versioning-and-api-stability).

## Unreleased

- Add a GFM syntax guide and a gallery of runnable Markdown examples with
  verified HTML output and styled browser previews.
- Remove two bundled test fixtures with unresolved individual provenance from
  new source snapshots, and add independently authored regression cases. The
  pinned backend and runtime behavior are unchanged.

## 1.0.0

First public release.

- Render Markdown with the vendored, unmodified GitHub cmark-gfm
  `0.29.0.gfm.13` (`27d942c8b0a62d192f616e5bf3578f4b6a89e180`) to HTML, XML,
  CommonMark, plain text, LaTeX, and man.
- Parse into a read-only, `Sendable`, `Hashable` Swift AST with typed node
  kinds, source ranges, footnotes, task lists, and table alignments, plus
  iterative visitors and walkers.
- Configure the five built-in GFM extensions and every cmark-gfm option.
  `MarkdownConfiguration()` and `MarkdownEngine()` both default to the GFM
  extensions; unsupported extension and option bits are rejected.
- Bound input size and AST size or depth with optional `MarkdownResourceLimits`.
- Report failures as `MarkdownEngineError` with an extensible `code` and
  context.
- Serialize all backend access through one lock, and rename the vendored C
  globals so SwiftGFM links next to other cmark copies.
- `swift-gfm` command line that mirrors `cmark-gfm`, including file arguments.
- Supports Swift 6.0 and later on macOS, Linux, iOS, tvOS, watchOS, visionOS,
  WebAssembly (WASI), and the Static Linux SDK.
- API reference and guides at
  https://thorfuchs.github.io/Swift-GFM/documentation/swiftgfm/.
