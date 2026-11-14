# SwiftGFM documentation

This index distinguishes the current package contract from the research that
led to it. The original mission evolved: the implemented product wraps a
pinned GitHub cmark-gfm backend and provides a separate read-only Swift AST.
Historical reports remain useful evidence, but their proposals and open
questions are snapshots rather than statements of the current API.

## Use the package

- [Package README](../README.md): requirements, installation, rendering, and CLI.
- [DocC catalog](../Sources/SwiftGFM/SwiftGFM.docc/SwiftGFM.md): API reference and guides.
- [Wrapper API](WRAPPER-API.md): formats, options, defaults, and backend boundary.
- [Read-only AST](AST.md): node kinds, walking, source positions, and ownership.
- [Backend configurations](PROFILES.md): cmark defaults and the GFM extension set.
- [Security](SECURITY.md): HTML handling and host responsibilities.
- [Resource limits](RESOURCE-LIMITS.md): optional input and Swift AST projection bounds.
- [License and notices](../NOTICE): the project's Apache license and third-party material.
- [Concurrency and process isolation](CMARK-CONCURRENCY.md): lock scope and limits.

## Verify behavior

- [Bundled cmark-gfm QA](BUNDLED-CMARK-QA.md): fixture provenance, exact comparisons, and round-trip differences.
- [Reproduction and qualification](REPRODUCTION.md): toolchains, commands, references, and CI evidence.
- [Repository quality audit](QUALITY-AUDIT-2026-11-14.md): findings, fixes, evidence, and remaining limits.
- [Published GFM reporting views](CONFORMANCE.md): experimental specification comparisons, separate from backend parity.
- [Fixture provenance](../Tests/SwiftGFMTests/Fixtures/cmark-gfm/README.md): upstream files and generated entity expectations.

## Architecture and historical research

- [Upstream strategy decision](UPSTREAM-DECISION.md): the accepted approach and its historical S0 assessment.
- [GitHub cmark-gfm API inventory](GITHUB-CMARK-API-INVENTORY.md): upstream API and wrapper investigation.
- [Direct cmark feasibility spike](CMARK-FEASIBILITY.md): historical swift-cmark experiment.
- [Swift Markdown dependencies](SWIFT-MARKDOWN-DEPENDENCIES.md) and [pure Swift alternatives](PURE-SWIFT-OPTIONS.md).
- [Swift Markdown against bundled fixtures](SWIFT-MARKDOWN-BUNDLED-GFM.md), [failure clusters](GFM-FAILURE-CLUSTERS.md), and [AST investigation](GFM-AST-INVESTIGATION.md).
- [Published GFM 15-example investigation](GFM-15-INVESTIGATION.md): historical fixture mapping and configuration questions.

Generated reports and DocC archives are excluded from Git; the commands above
recreate them. The [test and analysis tools](../Tools) are development tools,
not production dependencies.
