# Read-only Swift AST

`MarkdownEngine.parse(_:)` parses with the engine's exact backend configuration
and returns a `MarkdownDocument: Sendable`. Its `source`, `configuration`, and
`root` are immutable. Each `MarkdownNode` has a typed `kind`, optional `range`,
and an ordered array of child nodes. The tree is a Swift-owned snapshot: no C
pointers or mutable C objects escape. The original source is retained so a
consumer can consult it, not because the AST is a lossless source serializer.

```swift
import SwiftGFM

let configuration = MarkdownConfiguration(extensions: .gfm, options: [.sourcePositions])
let engine = MarkdownEngine(configuration: configuration)
let document = try engine.parse("# Hello *Swift*\n")

struct TextCollector: MarkdownVisitor {
    var values: [String] = []
    mutating func visit(_ node: MarkdownNode) -> MarkdownWalkControl {
        if case let .text(value) = node.kind { values.append(value) }
        return .visitChildren
    }
}
var collector = TextCollector()
document.walk(&collector)
// collector.values == ["Hello ", "Swift"]
```

The visitor is called in depth-first preorder. Return `.skipChildren` to prune
the current subtree or `.stop` to end traversal. `document.walk { ... }` also
accepts a throwing closure. `MarkdownWalker` and `MarkdownNode.walk` can walk a
subtree. Traversal uses an explicit stack, and the visitor can maintain its own
state. Swift arrays have value semantics; mutating a caller's copy cannot change
the parsed node. Node values share immutable flat storage. Retaining any node
keeps the complete parsed tree's storage alive, and reading `children` creates
an array of child values. Releasing a deeply nested tree does not recursively
destroy a chain of child nodes.

## Mapping and scope

The adapter copies the actual C tree under the same lock as rendering. It does
not parse the backend's XML, which can contain XML-invalid characters and raw
attribute whitespace that a normal XML parser changes. The XML is a useful
independent comparison of fields that it serializes, but it is not a complete
representation of all C metadata. The AST also exposes C list tightness and
delimiter, code fence details, table alignments and task-list state. The
document and inline/block nodes, literals, link destination/title, lists,
headings, code, raw HTML, strikethrough, tables, task items and custom nodes have
explicit enum cases. Footnote definition/reference cases are available when
`.footnotes` is enabled. Their literals are backend values: a resolved
reference literal can be a generated number rather than the original label.

This cmark revision's type-string function returns `<unknown>` for its built-in
footnote nodes, so its XML output does not provide a valid XML tag for them.
The adapter recognizes the public C enum values directly. Unknown node kinds,
unexpected values, and invalid UTF-8 from backend node accessors cause an error
rather than being silently discarded. The adapter does not expose every
internal C field, such as footnote reference counters or C user data, and does
not promise a stable copy of internal data across backend revisions.

The tree is independent of swift-markdown and does not claim to equal the tree
produced by that library. It is not a promise that cmark implements all formal
GFM or CommonMark requirements. `render(_:as:)` still invokes cmark's renderers
on a fresh C parse. There is no API to rewrite or render a Swift AST; rendering
the original `document.source` is a separate parse, not rendering the snapshot.

## Source ranges

Enable `.sourcePositions` on the engine to obtain ranges. Otherwise `range` is
`nil`, because this cmark revision does not calculate all multiline inline
positions consistently without that option. Even with the option, some nodes
have no range. Coordinates are the backend's raw line and column values, with
an inclusive end. They are not Swift `String.Index` values; tabs, Unicode,
synthetic nodes, and zero or unusual coordinates require care. The package
does not claim ranges are lossless source slices or independently correct for
all inputs.

## Concurrency and limits

`MarkdownEngine`, `MarkdownDocument`, `MarkdownNode`, kinds and metadata are
`Sendable`. Native parsing and conversion share the module's lock; traversal of
an already returned tree requires no C access or library lock. Optional
[resource limits](RESOURCE-LIMITS.md) can bound input bytes and Swift AST node
count or depth; these limits default to unlimited and do not bound cmark's own
allocation or execution time. A synchronous C call does not become cancellable
when invoked from a Swift task. The existing cmark allocator, raw HTML, URL
policy, and host security limitations also apply.

## Validation

On Linux with Swift 6.4.2 and GitHub cmark-gfm commit
`27d942c8b0a62d192f616e5bf3578f4b6a89e180`, the XML-visible projection,
including raw source positions, matched the independently built C XML output on
670/670 upstream-enabled examples using the flags supplied by each example,
and on 670/670 with all five GFM extensions enabled. Upstream examples 279 and
280 are marked disabled and were not included. This comparison does not test
all C-only properties, footnotes, malformed XML, arbitrary inputs, or formal
specification conformance. Focused Swift tests cover several of those omitted
properties and cases. On 2026-11-14, GitHub Actions also passed the Swift tests
in debug and release on macOS arm64 with Xcode 27.2 and Apple Swift 6.4.2; that
job did not run the Linux-only independent C reference or sanitizer checks.
See [REPRODUCTION.md](REPRODUCTION.md) for the commands and CI evidence.

The Linux Swift test suite also passed in debug and release configurations and
under Thread Sanitizer. The C object contained thread-sanitizer instrumentation.
Address Sanitizer passed with leak detection disabled; that run does not test
for memory leaks. The concurrency tests exercise mixed parse/render operations
and sharing an immutable snapshot across tasks. These tests are evidence for the
exercised cases, not a proof of thread safety or bounded resource usage.
