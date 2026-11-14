# Swift-GFM

SwiftGFM is a Swift package wrapping the original GitHub cmark-gfm C source at commit `27d942c8b0a62d192f616e5bf3578f4b6a89e180` (backend version `0.29.0.gfm.13`). It offers a string-to-string rendering operation with six output formats and a read-only, `Sendable` Swift AST. C pointers and the mutable C tree stay internal; the XML output is cmark's native serialization of that tree.

```swift
import SwiftGFM

let compiler = MarkdownEngine()
let html = try compiler.render("# Hello *Swift*", as: .html)
let xml = try compiler.render("# Hello *Swift*", as: .xml)
print(MarkdownEngine.backendVersion)
print(MarkdownEngine.backendRevision)
```

Parse and walk a separately owned Swift tree:

```swift
let document = try compiler.parse("# Hello *Swift*")
document.walk { node in
    if case let .text(value) = node.kind {
        print(value)
    }
    return .visitChildren
}
```

The AST is a read-only projection of the configured cmark parse; it is not a
Swift Markdown `Document` or a lossless source representation. The package does
not render or rewrite Swift ASTs. Enable `.sourcePositions` in the engine
configuration to include cmark source coordinates. See [the AST guide](Documentation/AST.md).

Formats are `.html`, `.xml`, `.commonMark`, `.plainText`, `.latex`, and `.man`. Configure extensions, options and wrap width when constructing an engine:

```swift
let configuration = MarkdownConfiguration(
    extensions: .gfm,
    options: [.sourcePositions, .allowUnsafeHTML],
    width: 0
)
let compiler = MarkdownEngine(configuration: configuration)
let xml = try compiler.render("# Hello", as: .xml)
```

The default `.gfm` configuration enables table, strikethrough, autolink, tag filter, and task-list extensions and retains cmark's default HTML policy. `.cmarkDefault` enables no extensions. `.allowUnsafeHTML` enables raw HTML and otherwise filtered unsafe links; neither mode is a general HTML sanitizer or the GitHub.com hosted rendering pipeline. The C renderer's CommonMark output is normalized and is not a lossless source serializer.

The compatibility goal is fidelity to the pinned GitHub C backend under explicit configuration, not a claim of complete formal CommonMark, GFM, or Jekyll conformance. There is no Jekyll profile. Parse and render calls through this module use one shared lock because this C revision has process-global mutable state; input/output limits and cancellation during C execution are not provided. SwiftPM compiles C and Swift together as one library product; direct C calls bypassing this wrapper's lock are outside its safety boundary.

```sh
swift test
printf '# Hello\n' | swift run swift-gfm html --unsafe
printf '# Hello\n' | swift run swift-gfm xml --sourcepos
swift run swift-gfm --version
```

The command-line tool starts with cmark's zero-extension defaults and accepts individual `-e` extensions and backend flags; run `swift-gfm --help` for the list. The API defaults to the `.gfm` convenience configuration.

`swift test` includes the pinned cmark-gfm repository's spec, extension,
regression, punctuation, and option fixtures. See the [bundled test guide](Documentation/BUNDLED-CMARK-QA.md)
for the explicit upstream skips and observed CommonMark round-trip differences.
Build the DocC archive with `sh Tools/build-docc.sh` using the Swift toolchain's
`docc` command.

See [the wrapper and XML reference](Documentation/WRAPPER-API.md), [the full C API inventory](Documentation/GITHUB-CMARK-API-INVENTORY.md), and [conformance and reproduction details](Documentation/REPRODUCTION.md). The C source and its complete upstream license notices are in [Vendor/GitHubCMark](Vendor/GitHubCMark). Linux x86_64 and macOS arm64 have passed the scoped CI tests described in the documentation. The source license notices apply to distributions containing the vendored C code.

The repository does not yet declare a license for SwiftGFM's own code. The
project owner must select one before the package can be published with clear
reuse terms; the vendored cmark notices continue to apply independently.
