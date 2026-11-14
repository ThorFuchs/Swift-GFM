# Limiting input and AST projection

Use optional limits to reject large inputs or stop copying oversized Swift trees.

```swift
import SwiftGFM

let limits = MarkdownResourceLimits(
    maximumInputUTF8Bytes: 1_000_000,
    maximumASTNodes: 100_000,
    maximumASTDepth: 1_000
)
let engine = MarkdownEngine(configuration: .init(extensions: .gfm, limits: limits))
let document = try engine.parse("# Hello\n")
```

All limits default to `nil`, meaning unlimited, and must be nonnegative.
``MarkdownResourceLimits/maximumInputUTF8Bytes`` counts the input string's
UTF-8 bytes before cmark runs; it applies to both parsing and rendering.
``MarkdownResourceLimits/maximumASTNodes`` and
``MarkdownResourceLimits/maximumASTDepth`` apply only when copying an AST for
``MarkdownEngine/parse(_:)``. The document root counts as one node at depth one.

Errors identify the limit kind, configured value, and observed value through ``MarkdownEngineError/resourceLimit``, ``MarkdownEngineError/limit``, and ``MarkdownEngineError/value``.
``MarkdownEngineError/invalidResourceLimit(_:value:)`` reports negative
settings; ``MarkdownEngineError/resourceLimitExceeded(_:limit:actual:)``
reports an exceeded bound.

These are not hard memory, output-size, or time budgets. cmark completes its C
parse before SwiftGFM checks AST node or depth limits, and task cancellation
does not interrupt an in-progress C call. See <doc:ConcurrencyAndSecurity>.
