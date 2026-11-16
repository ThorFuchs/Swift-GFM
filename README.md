# Swift-GFM

[![CI](https://github.com/ThorFuchs/Swift-GFM/actions/workflows/ci.yml/badge.svg)](https://github.com/ThorFuchs/Swift-GFM/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
![Platforms: macOS | iOS | Linux | WebAssembly](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Linux%20%7C%20WebAssembly-lightgrey.svg)

[Read the documentation →](https://thorfuchs.github.io/Swift-GFM/documentation/swiftgfm/)

SwiftGFM renders GitHub Flavored Markdown in Swift with GitHub's own
[cmark-gfm](https://github.com/github/cmark-gfm) C library, and gives you a
read-only, `Sendable` Swift syntax tree of the same parse. It vendors the
unmodified upstream source at commit `27d942c8b0a62d192f616e5bf3578f4b6a89e180`
(backend version `0.29.0.gfm.13`) and has no dependencies.

```swift
import SwiftGFM

let html = try MarkdownEngine().render("| a | b |\n|---|---|\n| ~~x~~ | www.example.com |\n")
```

## Why SwiftGFM

- **The upstream backend, unmodified.** SwiftGFM compiles GitHub's C source
  as is. CI renders every bundled upstream fixture in all six output formats
  with both SwiftGFM and an independently built cmark-gfm at the same commit,
  and requires identical bytes.
- **A typed, Swift-owned AST.** `parse(_:)` copies the C tree into immutable
  values with typed node kinds, source ranges, and walkers. No C pointers
  escape, and deeply nested documents do not overflow the stack.
- **Safe to combine with other cmark copies.** The vendored C globals are
  renamed at build time, so SwiftGFM links next to
  [Swift Markdown](https://github.com/swiftlang/swift-markdown) and its
  `swift-cmark` fork, each with its own state.
- **Explicit configuration and limits.** Extensions and options map one-to-one
  to cmark-gfm's, unsupported bits are rejected, and optional limits bound
  input size and AST size or depth.

SwiftGFM's compatibility contract is **fidelity to the pinned backend under the
chosen configuration**. It does not claim complete conformance to every
published CommonMark or GFM specification example, the GitHub.com hosted
renderer (which post-processes and sanitizes HTML), or Jekyll. If you need to
edit and re-render a Markdown tree, use Swift Markdown; SwiftGFM's tree is
read-only.

## Requirements and installation

SwiftGFM requires Swift 6.0 or newer and has no platform minimums.

| Platform | CI coverage |
| --- | --- |
| macOS (arm64) | Tests, Thread Sanitizer |
| Linux (x86_64, arm64) | Tests; on x86_64 also sanitizers and comparison with upstream |
| iOS, tvOS, watchOS, visionOS, Mac Catalyst | Build |
| WebAssembly (WASI), Static Linux SDK (musl) | Build |
| Android, Windows | Not tested |

CI tests Swift 6.0 through 6.4 on Linux. See [testing and verification](Documentation/TESTING.md)
for the checks and what they do not establish.

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ThorFuchs/Swift-GFM.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [.product(name: "SwiftGFM", package: "Swift-GFM")]
    )
]
```

## Render Markdown

```swift
import SwiftGFM

let engine = MarkdownEngine()
let html = try engine.render("# Hello *Swift*\n", as: .html)
let xml = try engine.render("# Hello *Swift*\n", as: .xml)
print(MarkdownEngine.backendVersion, MarkdownEngine.backendRevision)
```

The six formats are `.html`, `.xml`, `.commonMark`, `.plainText`, `.latex`, and
`.man`. XML is the backend's AST serialization, not XHTML. CommonMark output
is normalized and is not a lossless source serializer.

The default engine enables table, strikethrough, autolink, tag-filter, and
task-list extensions, and so does `MarkdownConfiguration()` when you omit
`extensions:`. Use `.cmarkDefault` or `extensions: []` for no extensions, or
select them explicitly:

```swift
let configuration = MarkdownConfiguration(
    extensions: [.table, .strikethrough],
    options: [.sourcePositions],
    width: 0
)
let configuredEngine = MarkdownEngine(configuration: configuration)
let result = try configuredEngine.render("# Hello\n")
```

The default backend policy filters raw HTML and some unsafe links.
`.allowUnsafeHTML` changes that behavior; neither mode is a complete HTML
sanitizer. See [security](Documentation/SECURITY-MODEL.md) for the host's
responsibilities.

Optional `MarkdownResourceLimits` can reject oversized UTF-8 input and bound
the size or depth of the Swift AST projection. Defaults are unlimited. These
checks do not impose a hard memory or time limit on cmark itself; see
[resource limits](Documentation/RESOURCE-LIMITS.md).

## Inspect a syntax tree

```swift
let document = try engine.parse("# Hello *Swift*\n")
document.walk { node in
    if case let .text(value) = node.kind {
        print(value)
    }
    return .visitChildren
}
```

The `Sendable` tree is a read-only projection of the configured cmark parse,
not a Swift Markdown `Document` or a lossless source representation. Enable
`.sourcePositions` to request backend coordinates. The package does not render
or rewrite Swift ASTs. See the [AST guide](Documentation/AST.md) for ownership,
visitor, source-range, and retention details.

Nodes and documents are `Hashable` and compare structurally, so two parses of
the same input with the same configuration are equal.

## Handle errors

Every failure is a `MarkdownEngineError`. Compare its `code` and read the
optional context:

```swift
let limited = MarkdownEngine(configuration: .init(limits: .init(maximumInputUTF8Bytes: 1_000_000)))
do {
    _ = try limited.render(untrustedInput)
} catch let error as MarkdownEngineError where error.code == .resourceLimitExceeded {
    print("input too large:", error.value ?? 0, "bytes")
}
```

## Command line

The `swift-gfm` executable mirrors the upstream `cmark-gfm` command line. It
reads the named files in order, or standard input:

```sh
swift run swift-gfm html README.md
printf '# Hello\n' | swift run swift-gfm xml --sourcepos
swift run swift-gfm html -e table -e autolink --unsafe notes.md
swift run swift-gfm --help
```

The CLI starts with cmark's zero-extension defaults; the library engine
defaults to the GFM extension set.

## Testing

```sh
swift test
```

The tests include the pinned backend's bundled fixtures, with explicit upstream
skips and documented round-trip differences. See
[bundled test coverage](Documentation/BUNDLED-CMARK-QA.md) and
[testing and verification](Documentation/TESTING.md) for the comparisons with
the upstream C executable.

## Versioning and API stability

SwiftGFM follows [Semantic Versioning](https://semver.org) from 1.0.0. The
public API of the `SwiftGFM` library is covered; the `swift-gfm` command line
and the development tools are not.

- **Major versions** remove or change public API, or add cases to public
  enums such as `MarkdownNodeKind`, `MarkdownOutputFormat`, or
  `MarkdownWalkControl`. Exhaustive `switch` statements over these enums keep
  compiling within a major version.
- **Minor versions** add API. This includes new `MarkdownEngineError.Code`
  values, new `MarkdownResourceLimit` values, new `MarkdownOptions`, and new error context
  properties, which are structs rather than enums for that reason; give
  `switch` statements over them a `default` case. Updating the vendored
  cmark-gfm revision is at least a minor version because rendered output can
  change. A backend update that requires new node kinds is a major version.
- **Patch versions** fix bugs. A security fix, including an upstream cmark-gfm
  fix, can be a patch version even if it changes output for affected inputs.

The native XML output, CommonMark round-trip text, and error descriptions are
backend or diagnostic output, not a stable schema.

## Security

See the [security policy](SECURITY.md) for supported versions and how to
report a vulnerability privately, and the [security model](Documentation/SECURITY-MODEL.md)
for what the package does and does not protect against.

## Contributing and support

See [CONTRIBUTING.md](CONTRIBUTING.md), [SUPPORT.md](SUPPORT.md), and the
[changelog](CHANGELOG.md). Participation follows the
[community standards](CODE_OF_CONDUCT.md).

## Documentation and licensing

The [API reference and guides](https://thorfuchs.github.io/Swift-GFM/documentation/swiftgfm/) are published from `main`. The
[documentation index](Documentation/README.md) covers the wrapper, AST,
security, concurrency, testing, and upstream updates. Build the DocC archive
locally with `sh Tools/build-docc.sh`.

SwiftGFM's original code is licensed under [Apache License 2.0](LICENSE). The
[NOTICE](NOTICE) identifies third-party material: the vendored cmark-gfm source
retains its own copyright and license notices, and specification fixtures have
separate terms. Distributors of binaries containing cmark-gfm must retain the
applicable upstream notices; see [Vendor/GitHubCMark/COPYING](Vendor/GitHubCMark/COPYING).
