# SwiftGFM documentation

## Use the package

- [Package README](../README.md): installation, rendering, AST, CLI, and versioning.
- [DocC catalog](../Sources/SwiftGFM/SwiftGFM.docc/SwiftGFM.md): API reference and guides.
- [Wrapper API](WRAPPER-API.md): formats, options, configurations, and the backend boundary.
- [Read-only AST](AST.md): node kinds, walking, source positions, and ownership.
- [Resource limits](RESOURCE-LIMITS.md): optional input and Swift AST projection bounds.
- [Concurrency and process isolation](CMARK-CONCURRENCY.md): the lock, its limits, and when to use a worker process.
- [Security model](SECURITY-MODEL.md): HTML handling and host responsibilities. Report vulnerabilities as described in the [security policy](../SECURITY.md).
- [License and notices](../NOTICE): the project's Apache license and third-party material.

## Verify and maintain

- [Testing and verification](TESTING.md): local checks, sanitizers, DocC, and comparisons with the upstream C executable.
- [Bundled cmark-gfm test coverage](BUNDLED-CMARK-QA.md): fixture provenance, exact comparisons, skips, and round-trip differences.
- [Fixture provenance](../Tests/SwiftGFMTests/Fixtures/cmark-gfm/README.md): upstream files, hashes, and the derived entity fixture.
- [Updating the vendored cmark-gfm](UPDATING-CMARK-GFM.md): how to move the pinned backend to a new upstream revision.

The [tools](../Tools) are development tools, not runtime dependencies. Generated
reports, reference builds, and DocC archives are excluded from Git.
