# SwiftGFM 1.1.0 candidate validation

This records pre-merge evidence for the optional math parser. It is not a
release announcement. The code tested below is commit
`46b5abebbca6baec4b955a18e3f1cdc6241d28f3`; the subsequent candidate
preparation changes documentation, the changelog and the security workflow.
A future merge commit and release tag require their own checks under
[RELEASING.md](../RELEASING.md).

## Scope and compatibility

The new HTML-only profile captures dollar-delimited math and returns ordered
HTML and formula pieces for a separate renderer. It is opt-in and has no KaTeX
dependency. Existing `MarkdownEngine.render(_:)`, `parse(_:)`, public enum
cases, the pinned backend, and the package dependency graph are unchanged.
The additions are compatible with the 1.x API and therefore proposed as a
minor release. New cases added to public enums in the future require a major
version under the [versioning policy](../README.md#versioning-and-api-stability).

The [math guide](MATHEMATICS.md) specifies delimiter precedence, supported
contexts and the complete documented fallback and security boundaries. In
particular, tables, image descriptions and code do not recognize math;
`allowUnsafeHTML` and NUL input are rejected; unclosed display math throws;
and currency detection is heuristic. The profile does not sanitize renderer
output or impose a hard cmark memory or time limit.

## Pre-merge evidence

- **macOS arm64:** Swift 6.4.2 ran the full Swift suite with an independently
  built C reference. The runner reported 59 tests; two upstream-disabled
  examples and one `<IGNORE>` expectation were separately skipped, not counted
  as passes. The independent CLI comparison matched 4,230 of 4,230 outputs
  across six formats; its inputs include the `<IGNORE>` case for backend parity
  only. AST comparison matched 670 of 670 enabled examples in each of two
  configurations; the two upstream-disabled cases were not counted as passes.
- **Linux arm64:** A separate session tested the exact code commit in a native
  Ubuntu 24.04.5 container with Swift 6.2.4. Its SwiftGFM suite and independent
  cmark comparisons passed, with the same three documented upstream skips.
  An experimental SwiftMD integration passed 29 adapter and six CLI tests with
  actual renderers. These are local test results, not GitHub CI results.
- **Integration:** On macOS, SwiftMD separately reported 38 adapter and six
  CLI tests with the same package code. A Chromium check displayed inline,
  display and fenced MathML plus SVG without page JavaScript. Integration
  used local development checkouts, not a published SwiftGFM 1.1.0 tag.
  A separate fresh macOS SwiftPM consumer using a local path dependency also
  built and exercised inline and display math. It is not a version-based
  release consumer.
- **Memory and concurrency:** Math-focused Address Sanitizer tests and a
  Thread Sanitizer concurrency test passed locally on macOS. ASan leak
  detection was disabled; the run does not establish absence of leaks or races.
- **Static analysis:** Apple Clang Static Analyzer 21.0.0 analyzed the two
  SwiftGFM C bridge files using the macOS arm64 debug build's project flags,
  with core, unix, security and opt-in taint checkers enabled. It reported no
  warnings. The Swift side, Linux build, and cross-translation-unit cmark and
  allocator behavior were not comprehensively modeled. The earlier CodeQL
  run does not cover this candidate; no fuzzing or independent security audit
  is claimed. A separate CodeQL workflow has been prepared for Swift and C;
  its results for the release commit still need review.

## Still required before publication

Merge the candidate through the protected main-branch process and obtain all
required CI checks on the exact release commit, including the Swift-version
matrix, upstream comparisons, sanitizers and documentation. Perform the
separately requested automated security scan on that commit and assess any
findings. Only after the maintainer explicitly requests publication, follow
[RELEASING.md](../RELEASING.md) for the annotated tag, GitHub release,
independent version-based SwiftPM consumer and Swift Package Index check.
The candidate evidence above is not a substitute for those release gates.
