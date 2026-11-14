# Security boundary

The C library's default HTML policy filters raw HTML and some unsafe links. `.allowUnsafeHTML` enables the backend's `CMARK_OPT_UNSAFE`; neither setting is a complete HTML sanitizer or a reproduction of GitHub.com hosted post-processing. Hosts must apply context-appropriate output policies.

The parser is native C in the application process. Rendering through `MarkdownEngine` is serialized with a shared lock to protect this C revision's process-global mutable state; code calling the C target directly bypasses that lock. Input length, memory, execution time and running-task cancellation are not bounded by the wrapper. The C default allocator may abort the process on allocation failure. XML output includes a DTD declaration, so consumers must configure their XML parser's external-entity behavior. See [CMARK-CONCURRENCY.md](CMARK-CONCURRENCY.md) for the design and [WRAPPER-API.md](WRAPPER-API.md) for current qualification.
