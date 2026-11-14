# Upstream strategy decision

**Status: accepted for the current package.** SwiftGFM vendors the original
GitHub cmark-gfm C source at `27d942c8b0a62d192f616e5bf3578f4b6a89e180` and
provides a Swift string-to-string rendering API plus a separate read-only
Swift AST. Its compatibility claim is fidelity to that backend under explicit
configuration, not complete CommonMark, GFM, GitHub.com, or Jekyll
conformance. No swift-markdown fork or runtime Swift Markdown dependency is used.

The SwiftPM integration preserves the upstream source and its notices, prefixes
C symbols to avoid observed collisions, and serializes wrapper calls with a
shared lock. The Swift AST copies exposed C data into immutable values and does
not expose the C tree. See [WRAPPER-API.md](WRAPPER-API.md), [AST.md](AST.md),
and [BUNDLED-CMARK-QA.md](BUNDLED-CMARK-QA.md) for the current contract and
evidence. The original strict profile gates are not claimed as passed.

## Historical S0 upstream assessment (2026-11-13)

The following assessment records what was known at S0. Statements about
provisional choices or missing implementation describe that date and are
superseded by the accepted decision above.

Status: provisional; gate not passed. Inspected swift-markdown `ea1d88be47afe8a731b3971d7b3fb7a3a6db1a5a` (tools 6.2, Swift language mode 5), its swift-cmark `gfm` branch at `437611671145d47e6d9679761b8a5987766f4ae5`, commonmark/cmark `d56b4bdced7563c7bd596f8f80dd0521eb8ca34a`, github/cmark-gfm `27d942c8b0a62d192f616e5bf3578f4b6a89e180`, and commonmark-spec `8a5f7646e9f67c3004f023d262b3e6b596afc2ed`. These are inspected snapshots, not package or reference pins. swift-markdown declares a branch dependency on swift-cmark and a DocC plugin; resolving its dependency graph reproducibly remains open.

1. CommonMark without a fork: plausible via direct cmark, not established. Public `Document(parsing:options:)` cannot select it: `CommonMarkConverter.parseString` attaches table, strikethrough, tasklist unconditionally and enables `CMARK_OPT_TABLE_SPANS`. Smart punctuation is on by default, but `.disableSmartOpts` disables it.
2. GFM without a fork: plausible via cmark-gfm, not established. Swift Markdown attaches neither autolink nor tagfilter. The core extensions library registers them, which is different from attaching them to a parser.
3. Reuse of the public AST unchanged: useful for normal traversal, but strict use is unproven. Its converter is internal and directly constructs its own nodes; a separate cmark parse cannot simply be passed into it through the public API. Source ranges and conversion semantics need differential tests.
4. Missing controls: per-extension attachment, full profile selection and rendering policies. Verify cmark options and extension versions against both independently pinned specs.
5. Lost constructs: not yet determined. The converter handles known node types and terminates on unknown types; this is not proof of lossless conversion, source preservation, or extension support.
6. `HTMLFormatter`: no evidence of exact conformance; its own serializer, escaping and raw HTML behavior must be tested separately. The string convenience overload parses using defaults. cmark's renderer suppresses unsafe HTML unless `CMARK_OPT_UNSAFE` is set; specification output and host safety are distinct.
7. A narrow direct cmark-gfm adapter may suffice for rendering, but CommonMark version drift, Swift interop, lifetime, concurrency, AST integration and byte-identical output must be demonstrated. Reference cmark and GFM spec versions differ; do not assume one latest parser passes both.
8. No fork is justified yet. If essential, the smallest candidate is upstream parser configuration plus an exposed, safe conversion boundary; exact change depends on proven failures. Consider an independent renderer first.

Swift Markdown supplies visitors, walkers, rewriters, Markdown and HTML formatters and copy-on-write markup. Do not duplicate them casually. No upstream source is vendored here and no fork has been created.

## Dependency-resolution experiment

On SwiftPM 6.2.3, a separate probe using the exact swift-markdown revision and a direct exact swift-cmark revision failed: SwiftPM reported two revision-based requirements (`gfm` and the commit SHA) for swift-cmark. Removing the direct requirement allowed resolution of the `gfm` branch at `437611671145d47e6d9679761b8a5987766f4ae5`. A lockfile may pin the branch for an application checkout, but downstream Swift packages resolve their own graphs; it is not a sufficient universal library pinning strategy. Evaluate versioned upstream releases, dependency mirrors or a minimal upstream change before adopting a dependency. This probe is not the production package dependency graph.

## Direct adapter measurements

The [feasibility spike](CMARK-FEASIBILITY.md) confirms that direct extension selection is available without a fork, but the inspected swift-cmark revision does not meet the CommonMark 0.31.2 gate unchanged (641/652). It also demonstrates lost tight/loose list metadata in the Swift Markdown public AST, differing source-position sequences, and unresolved cross-package symbol/dependency issues. The production dependency and AST strategy remain open; a fork is not yet established as the smallest fix.

## Revised user direction: direct GitHub C wrapper

The user has chosen to evaluate a narrow string-to-string Swift wrapper over the literal GitHub cmark-gfm source, with backend fidelity as the claim rather than unqualified specification conformance. The [C API inventory and literal-source SwiftPM experiment](GITHUB-CMARK-API-INVENTORY.md) record the six renderers, options, limitations and parity evidence. This is an experimental direction; the public package does not yet implement the wrapper. The original strict CommonMark/GFM/Jekyll qualification results remain historical evidence, not passed gates. Crucially, the inspected GitHub C revision has unsynchronized global mutable parser state; the earlier swift-cmark concurrency test does not apply.

## Implemented user-directed wrapper

The main product now wraps the literal pinned GitHub C source with one string-to-string `render(_:as:)` API across six formats. XML is the native cmark AST serialization. Calls are serialized through a shared lock, and C globals are build-time prefixed `swiftgfm_` without altering upstream source. Linux parity, Thread Sanitizer and Swift Markdown coexistence results are in [WRAPPER-API.md](WRAPPER-API.md). The original independent specification and Jekyll gates have not been met and are not claimed.
