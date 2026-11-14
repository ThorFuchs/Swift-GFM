# cmark-gfm concurrency and process isolation

The public wrapper implements the conservative shared-lock design below. Linux stress and Thread Sanitizer checks passed; those checks are not a complete concurrency guarantee. The production target vendors the literal GitHub `cmark-gfm` source at commit `27d942c8b0a62d192f616e5bf3578f4b6a89e180`; `Experiments/GitHubCMarkProbe` contains a separate historical feasibility copy.

## Build and process model

SwiftPM normally compiles Swift and C as separate targets/modules, then links them into the executable or library product. The C target can be an internal implementation dependency; consumers need not see its API. Static and dynamic linking differ in packaging, not in process isolation: a loaded C library normally executes in the same process and shares its address space with Swift. A subprocess exists only if the application explicitly launches another process. A separate SwiftPM module or separate parser object is not a process boundary.

An executable containing this C code can still depend on system runtime libraries, and details of static/dynamic loading and symbols vary by platform. Do not promise a single machine-code module or a single-file binary solely because the public product is one Swift module.

## Shared state in the pinned C revision

Separate parser instances give each operation its own parser and tree, but are not enough to eliminate all shared state:

* `extensions/core-extensions.c` uses an unsynchronized static `registered` variable during extension initialization.
* `src/registry.c` maintains a process-image global extension registry.
* `src/inlines.c` has mutable static special-character tables; `src/blocks.c` modifies them around inline parsing when extensions are in use.
* `src/arena.c` implements an arena with global mutable state. The existing probe uses the default allocator, not that global arena.

The earlier 2,000-operation concurrency stress test used Swift's *different* `swift-cmark` revision, which has different synchronization behavior. It does not qualify this GitHub source. The C default allocator can call `abort()` on allocation failure; Swift `throws` cannot intercept that abort.

## Conservative in-process design

The most straightforward first production candidate is one internal, shared serialization boundary around **all** interactions with this C library copy. Every render uses a fresh parser, internal tree and output buffer. Registration, configuration, feeding, finishing, rendering, copying to Swift and freeing happen inside that same boundary, without suspension or escaped C pointers. Use the normal allocator initially and do not call process-global plugin release during normal operation. Bound input and queue sizes where appropriate.

Two reasonable Swift facades over that boundary:

1. A synchronous, `Sendable` value API whose implementation acquires one shared lock for the entire C operation. Calls from different actors are safe relative to each other if all use this same lock, but callers wait synchronously.
2. An async API using one shared actor or a dedicated serial worker queue. Other actors can `await` the result; the C operation remains synchronous inside the boundary. An actor must not suspend between creating C state and finishing cleanup, because actor methods can interleave at suspension points. An actor is not automatically a dedicated OS thread; a long synchronous C call can occupy a cooperative executor thread. A dedicated bounded worker queue can provide more predictable scheduling.

Multiple actor or compiler instances, each with its own lock, **do not** protect global C state. A wrapper-local lock is effective only for accesses that all respect it. If other dependencies call the same loaded C symbols directly, or symbol interposition makes them share state, separate integration or symbol isolation is necessary. Validate the actual link configuration; do not assume all C globals are uniquely private merely because a Swift target is named separately.

A lock/actor can prevent concurrent access through the controlled boundary; it does not isolate memory corruption, crashes, process aborts or HTML security policy. It also does not make an ongoing C call cooperatively cancellable. A request can be cancelled before it starts, but a safe hard deadline on a running unmodified C function is not generally provided by Swift task cancellation.

## When a subprocess helps

Launching a separate worker process gives a separate address space and a separate C global state, can contain a worker crash and allows a supervisor to terminate a worker on a hard timeout. One fresh process per request provides stronger reset/isolation at the cost of startup, IPC and deployment overhead. A bounded worker pool can amortize startup and run requests in parallel across processes; process each worker's requests serially unless its own thread safety is proven. Reused workers retain state between requests.

A process boundary is not automatically a security sandbox: file system/network access, permissions, resource limits, output sanitization and child-process availability depend on the host OS and deployment. Some Apple platform environments restrict launching helper executables. Avoid making subprocess execution a mandatory library dependency without platform qualification.

## Proposed qualification before shipping

* Exercise mixed profiles, extensions, formats, repeated and concurrent Swift callers against the pinned single-process reference output; test cancellation while queued and failure cleanup.
* Run appropriate thread and memory sanitizers against instrumented Swift **and C** where supported; confirm C module and all wrapper paths participate in the same serialization boundary.
* Audit interactions with other cmark users, linking/symbol visibility, global initialization and memory allocators. Verify Linux and macOS separately.
* Benchmark throughput, memory and tail latency for the in-process serial design and, if required, a bounded process-worker design. A stress test that happens to pass does not prove data-race freedom.
* Document raw HTML/unsafe-link rendering separately from GitHub-hosted sanitization. Do not promise in-process hard timeouts, complete recovery from allocation failure or bounded memory unless independently implemented and verified.

## Implemented wrapper update

`MarkdownEngine` uses a single shared `NSLock` for registration and each full parser/tree/render/free operation. The vendored C source is unchanged; 278 global symbols are renamed with `swiftgfm_` via compile-time definitions, avoiding the duplicate symbols observed with Swift Markdown in a Linux coexistence probe. Tests exercised 1,200 mixed concurrent calls and passed with Thread Sanitizer on Linux; the C objects contained sanitizer instrumentation. This does not qualify macOS, external code that deliberately calls the prefixed C functions outside the wrapper, cancellation or crash isolation. See [WRAPPER-API.md](WRAPPER-API.md).
