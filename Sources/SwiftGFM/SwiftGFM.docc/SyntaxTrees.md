# Inspecting a syntax tree

Parse into an immutable, `Sendable` Swift value and walk its nodes.

## Parse and walk

```swift
import SwiftGFM

let engine = MarkdownEngine()
let document = try engine.parse("# Hello *Swift*\n")

struct TextCollector: MarkdownVisitor {
    var text: [String] = []

    mutating func visit(_ node: MarkdownNode) -> MarkdownWalkControl {
        if case let .text(value) = node.kind { text.append(value) }
        return .visitChildren
    }
}

var collector = TextCollector()
document.walk(&collector)
// collector.text == ["Hello ", "Swift"]
```

``MarkdownNode/kind`` is a ``MarkdownNodeKind`` enum with associated values for
properties including list tightness, link titles, code fences, table alignment,
and task-list state. ``MarkdownNode/children`` preserves backend order. The
walker visits nodes in depth-first preorder; return
``MarkdownWalkControl/skipChildren`` to prune a subtree or
``MarkdownWalkControl/stop`` to finish early. Closure-based walking can throw.

## Source positions and ownership

Add ``MarkdownOptions/sourcePositions`` to the engine configuration to request
backend source ranges. Some nodes may still have no range. Coordinates are raw
cmark coordinates, not Swift string indices, and should not be treated as
guaranteed source slices. ``MarkdownDocument/source`` retains the input.

The tree is a projection of the C parser's exposed data. It is not the official
Swift Markdown library's tree and does not capture every internal cmark field or
every original spelling choice. No C pointer escapes into the Swift tree. The
package does not rewrite or render Swift trees; rendering the original source
performs a separate cmark parse.
