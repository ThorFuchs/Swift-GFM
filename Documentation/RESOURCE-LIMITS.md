# Optional resource limits

`MarkdownResourceLimits` adds opt-in guards without changing the default backend
configuration or its output. Each value is an optional nonnegative integer;
`nil` means unlimited. Negative values cause
`MarkdownEngineError.invalidResourceLimit` when the engine is used.

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

`maximumInputUTF8Bytes` counts the original Swift string's UTF-8 bytes and is
checked before cmark is invoked by either `parse` or `render`. An empty string
has zero bytes; embedded NUL is counted before cmark processes it.

`maximumASTNodes` and `maximumASTDepth` apply only to `parse`. The document root
counts as one node and has depth one. They are checked as SwiftGFM copies the C
tree into Swift storage. Exceeding a limit throws
`MarkdownEngineError.resourceLimitExceeded` with the limit kind, configured
value, and observed value at the point of failure. A zero node or depth limit
therefore rejects even an empty document's root. These AST limits do not affect
the string-to-string `render` operation.

The AST guards execute **after cmark has parsed the complete input**. Neither
they nor the input-byte guard guarantee a maximum amount of C memory, rendered
output, CPU time, or wall time. Swift task cancellation does not interrupt a
running C call. Hosts that need hard timeouts, crash isolation, or OS-enforced
memory limits need an appropriately supervised process boundary. Choosing
limits and sanitizing rendered output remain host responsibilities.
