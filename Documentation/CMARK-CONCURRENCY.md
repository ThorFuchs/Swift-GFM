# Concurrency and process isolation

SwiftGFM runs the vendored GitHub cmark-gfm C library in-process. This page
explains how calls are synchronized, what that protects, and when a host needs
a process boundary instead.

## Shared state in the pinned C revision

Each operation creates its own parser and tree, but the C library also has
process-wide mutable state:

- `extensions/core-extensions.c` registers the built-in extensions through an
  unsynchronized static flag.
- `src/registry.c` keeps a global extension registry.
- `src/inlines.c` has mutable static special-character tables, which
  `src/blocks.c` modifies around inline parsing when extensions are in use.
- `src/arena.c` implements a global arena allocator. SwiftGFM uses the default
  allocator instead.

Separate parser instances alone are therefore not safe to use concurrently.

## How SwiftGFM synchronizes

`MarkdownEngine` uses one module-wide lock for the complete C lifecycle of each
call: extension registration, parser creation, feeding, finishing, rendering or
copying to the Swift AST, and cleanup. No C pointer escapes the locked region,
and nothing suspends inside it. `MarkdownEngine`, `MarkdownDocument`, and
`MarkdownNode` are `Sendable`; traversing a returned tree needs no lock.

The vendored C globals are renamed with a `swiftgfm_` prefix at compile time,
without modifying the upstream source. Another cmark copy in the same process,
such as the one in Swift Markdown, therefore has separate state and does not
need SwiftGFM's lock.

The lock protects only calls made through `MarkdownEngine`. Code that calls the
prefixed C functions directly bypasses it.

## Consequences for callers

- Calls are synchronous and serialized process-wide. A task that waits for the
  lock occupies its thread, and parallel callers do not gain throughput.
- Swift task cancellation does not interrupt a running C call.
- The C default allocator can abort the process on allocation failure; Swift
  `throws` cannot intercept that.
- Optional [resource limits](RESOURCE-LIMITS.md) reject oversized input and
  bound the Swift AST, but are not hard memory or time budgets.

## When a separate process helps

A worker process has its own address space and C state. It can contain a crash
or abort, and a supervisor can enforce a hard timeout or an OS memory limit by
terminating it. A pool of workers can render in parallel. The costs are
startup, IPC, and deployment complexity, and some Apple platforms restrict
launching helper processes. A process boundary is not automatically a security
sandbox: file-system and network access still depend on how the host
configures it.

Use a process boundary when rendering untrusted input with hard latency or
availability requirements. For trusted or size-limited input, the in-process
engine is usually sufficient.

## Verification

CI runs a concurrency test of 1,200 mixed parse and render calls across
configurations, and runs the full suite under Thread Sanitizer on Linux and
macOS with the C objects instrumented. This is evidence for the exercised
interleavings, not a proof of data-race freedom. See [TESTING.md](TESTING.md).
