# ``SwiftGFM``

Render Markdown with the pinned GitHub cmark-gfm backend and inspect a read-only Swift syntax tree.

## Overview

SwiftGFM wraps GitHub's cmark-gfm C library in-process. It provides six rendering
targets and a separate, Swift-owned tree suitable for visitors and walkers. Its
compatibility contract is fidelity to the pinned backend and chosen options,
not a claim that every published specification example or GitHub.com rendering
behavior is reproduced.

```swift
import SwiftGFM

let engine = MarkdownEngine()
let html = try engine.render("# Hello *Swift*\n", as: .html)
let document = try engine.parse("# Hello *Swift*\n")
```

## Topics

### Guides

- <doc:GettingStarted>
- <doc:Rendering>
- <doc:SyntaxTrees>
- <doc:ConcurrencyAndSecurity>
- <doc:BundledConformance>

### Parsing and rendering

- ``MarkdownEngine``
- ``MarkdownConfiguration``
- ``MarkdownOutputFormat``
- ``MarkdownExtensions``
- ``MarkdownOptions``
- ``MarkdownEngineError``

### Inspecting a document

- ``MarkdownDocument``
- ``MarkdownNode``
- ``MarkdownNodeKind``
- ``MarkdownSourceRange``
- ``MarkdownSourcePosition``
- ``MarkdownCodeFence``
- ``MarkdownListStyle``
- ``MarkdownListDelimiter``
- ``MarkdownTableAlignment``

### Traversal

- ``MarkdownVisitor``
- ``MarkdownWalker``
- ``MarkdownWalkControl``
