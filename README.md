# Swift-GFM

SwiftGFM is a Swift package for rendering Markdown with GitHub's cmark-gfm
backend and inspecting a read-only Swift syntax tree. It vendors the original C
source at commit `27d942c8b0a62d192f616e5bf3578f4b6a89e180` (backend version
`0.29.0.gfm.13`) and has no runtime dependency on Ruby or an application
framework.

Its compatibility contract is **fidelity to the pinned backend under the
chosen configuration**. It does not claim complete conformance to every
published CommonMark or GFM specification example, the GitHub.com hosted
renderer, or Jekyll.

## Requirements and installation

The package requires Swift tools 6.4 or newer. The recorded CI runs use Swift
6.4.2 on Linux x86_64 and macOS arm64; see [reproduction and qualification](Documentation/REPRODUCTION.md)
for the exact scope.

Add the package to your `Package.swift`, replacing `<reviewed-commit-sha>` with
a revision you have reviewed. The repository is private, so the machine
resolving it needs GitHub access. No release tag is currently provided.

```swift
dependencies: [
    .package(
        url: "https://github.com/ThorFuchs/Swift-GFM.git",
        revision: "<reviewed-commit-sha>"
    )
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
task-list extensions. Use `.cmarkDefault` for no extensions, or select them
explicitly:

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
sanitizer. See [security](Documentation/SECURITY.md) for the host's
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

## Command line and tests

```sh
swift test
printf '# Hello\n' | swift run swift-gfm html --unsafe
printf '# Hello\n' | swift run swift-gfm xml --sourcepos
swift run swift-gfm --help
```

The CLI starts with cmark's zero-extension defaults; the library engine
defaults to the GFM extension set. Tests include the pinned backend's bundled
fixtures, with explicit upstream skips and documented round-trip differences.
See [bundled test coverage](Documentation/BUNDLED-CMARK-QA.md).

## Documentation and licensing

Start with the [documentation index](Documentation/README.md) or the
[DocC catalog](Sources/SwiftGFM/SwiftGFM.docc/SwiftGFM.md). Build a local DocC
archive with `sh Tools/build-docc.sh` and a toolchain that provides `docc`.

SwiftGFM's original code is licensed under [Apache License 2.0](LICENSE). The
[NOTICE](NOTICE) identifies third-party material: the vendored cmark-gfm source
retains its own copyright and license notices, and specification fixtures have
separate terms. Distributors of binaries containing cmark-gfm must retain the
applicable upstream notices; see [Vendor/GitHubCMark/COPYING](Vendor/GitHubCMark/COPYING).
