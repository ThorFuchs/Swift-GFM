# SwiftGFM wrapper API

The public rendering surface is `MarkdownEngine.render(_:as:) -> String` (throwing). The separate `parse(_:)` API returns a read-only Swift tree; see [AST.md](AST.md). Construct an immutable engine with a `MarkdownConfiguration` containing built-in extensions, C options, and wrap width. `.gfm` enables the five GFM-related built-in extensions, as does `MarkdownConfiguration()` when `extensions:` is omitted; `.cmarkDefault` enables none. These names identify configurations of the pinned C library, not independent claims of complete formal specification conformance. The default HTML policy is cmark's default; `.allowUnsafeHTML` changes it. Width must be between zero and `Int32.max`; zero requests no wrapping. The engine exposes the C version string and pinned source commit separately.

```swift
let engine = MarkdownEngine(configuration: .init(
    extensions: .gfm,
    options: [.allowUnsafeHTML, .sourcePositions],
    width: 0
))
let html = try engine.render(markdown, as: .html)
let astXML = try engine.render(markdown, as: .xml)
let latex = try engine.render(markdown, as: .latex)
```

The other formats are `.commonMark`, `.plainText`, and `.man`. XML is the pinned C library's **native AST serialization**, not XHTML. It includes cmark node kinds, nesting, literals and some node attributes; `.sourcePositions` requests source-position attributes. It is not a promise of lossless original Markdown, complete C node metadata, a stable schema across future backend revisions, or a JSON API. Some valid Swift strings produce output that is not well-formed XML, and XML attributes are subject to whitespace normalization when read by a standard XML parser. This backend's footnote node names also produce invalid XML tags. The output includes the library's `CommonMark.dtd` declaration; consumers choose their own XML-parser external-entity policy. For in-memory inspection without XML parsing, use the separately owned Swift tree described in [AST.md](AST.md).

The package wraps the original GitHub C source in-process. A single module-wide `NSLock` guards registration and the complete parser/tree/render/free or parser/tree/copy/free lifecycle for calls through `MarkdownEngine`. Each call owns its parser and tree. 278 C globals are renamed at build time with a `swiftgfm_` prefix without modifying the vendored upstream source, so SwiftGFM can be linked next to other cmark copies, such as the one in Swift Markdown. Calls that bypass this wrapper and invoke its private prefixed C functions directly are not protected by the lock. Calls block synchronously; cancellation does not interrupt a C operation. The default C allocator can abort on allocation failure, which Swift `throws` cannot recover from. Optional [resource limits](RESOURCE-LIMITS.md) default to unlimited and do not provide hard C memory or execution-time budgets.

The CLI provides the six formats as `swift-gfm html|xml|commonmark|plaintext|latex|man`; it reads valid UTF-8 from stdin. Unlike the library's GFM convenience default, the CLI starts with cmark's zero-extension defaults, and allows `-e table`, `-e strikethrough`, `-e autolink`, `-e tagfilter`, `-e tasklist`, and `-e footnotes`. `swift-gfm --help` lists the wrapped flags. This is an in-process API; the test harness invokes its CLI as a subprocess only to perform comparisons.

## Configurations

`MarkdownConfiguration.cmarkDefault` selects the pinned parser with no extensions.
`.gfm`, which is also what `MarkdownConfiguration()` and `MarkdownEngine()` use,
attaches the built-in table, strikethrough, autolink, tag-filter, and task-list
extensions. Footnotes are a separate option, `.footnotes`. Options, extensions,
and width can be combined freely. These are configurations of the pinned C
library, not claims of complete CommonMark or GFM specification conformance;
there is no Jekyll or GitHub.com profile.

## Verification

CI compares the CLI with an independently built pinned C executable for all six
formats across every source-enabled bundled fixture input (4,482 byte
comparisons), runs the upstream spec runner against the CLI, and runs the Swift
tests in debug, release, and under sanitizers on Linux and macOS. The
string-based CLI rejects invalid UTF-8 before the engine. See
[TESTING.md](TESTING.md) and [bundled test coverage](BUNDLED-CMARK-QA.md).
