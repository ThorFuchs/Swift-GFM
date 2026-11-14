# Concurrency and security

Understand the in-process C boundary and choose an HTML policy for your host.

## Concurrency

``MarkdownEngine`` and the returned Swift tree are `Sendable`. Calls through the
wrapper use a shared lock for the complete C parser, tree, render or projection,
and cleanup lifecycle. Once returned, traversing a Swift tree needs no C access
or library lock. Calls that bypass the wrapper are outside this synchronization
boundary.

These operations are synchronous. A task waiting for the lock can occupy an
executor thread, and task cancellation does not interrupt a running C call.
Optional <doc:ResourceLimits> can bound input bytes and the Swift AST
projection, but default to unlimited. They do not impose hard C memory,
output-size, or execution-time limits. A host that needs hard deadlines or
crash isolation needs a separate process boundary.

## Output policy

The default cmark HTML mode filters raw HTML and certain unsafe link
destinations. ``MarkdownOptions/allowUnsafeHTML`` asks cmark to emit them. Neither
choice is a general-purpose sanitizer, and the GFM extensions do not reproduce
the complete GitHub.com hosted rendering and security pipeline. Choose a
sanitization policy appropriate to where your application embeds the output.
