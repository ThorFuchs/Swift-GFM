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

The package wraps the original GitHub C source in-process. A single module-wide `NSLock` guards registration and the complete parser/tree/render/free or parser/tree/copy/free lifecycle for calls through `MarkdownEngine`. Each call owns its parser and tree. 278 C globals are renamed at build time with a `swiftgfm_` prefix without modifying the vendored upstream source, preventing observed duplicate symbols when linking the separate Swift Markdown package on Linux. Calls that bypass this wrapper and invoke its private prefixed C functions directly are not protected by the lock. Calls block synchronously; cancellation does not interrupt a C operation. The default C allocator can abort on allocation failure, which Swift `throws` cannot recover from. Optional [resource limits](RESOURCE-LIMITS.md) default to unlimited and do not provide hard C memory or execution-time budgets.

The CLI provides the six formats as `swift-gfm html|xml|commonmark|plaintext|latex|man`; it reads valid UTF-8 from stdin. Unlike the library's GFM convenience default, the CLI starts with cmark's zero-extension defaults, and allows `-e table`, `-e strikethrough`, `-e autolink`, `-e tagfilter`, `-e tasklist`, and `-e footnotes`. `swift-gfm --help` lists the wrapped flags. This is an in-process API; the test harness invokes its CLI as a subprocess only to perform comparisons.

## Qualification as of 2026-11-14

Linux x86_64, Swift 6.4.2: the wrapper CLI matched the independently built pinned C CLI byte-for-byte for each of six output formats across 670 upstream-enabled inputs with fixture-specific extensions and unsafe HTML enabled: 4,020/4,020 comparisons; two source-disabled examples excluded. A separate matrix matched 336/336 combinations on two valid UTF-8 inputs, 14 individual option sets, two extension sets, and six formats. The String-based CLI intentionally rejects invalid UTF-8 before the engine. These are backend parity checks, not full formal specification conformance.

Swift tests pass in debug and release builds and cover six formats, XML inspection, default/unsafe behavior, invalid configuration, and 1,200 concurrent calls over mixed configurations and formats. GitHub Actions also passed these tests and the Python tooling tests on macOS arm64 with Xcode 27.2 and Apple Swift 6.4.2. Thread Sanitizer completed the suite on Linux with the relevant C objects instrumented; this is evidence, not a proof of all possible interleavings or other callers. A separate Linux consumer successfully links SwiftGFM with official Swift Markdown and verifies distinct autolink behavior. `nm` checked 281 defined C globals: 278 prefixed upstream symbols and three prefixed SwiftGFM integration helpers. The macOS job did not run the independent C-reference or sanitizer checks; other architectures, resource limits, cancellation and host security remain unqualified. The original historical GFM/CommonMark spec reports remain evidence and have not become passing release gates.
