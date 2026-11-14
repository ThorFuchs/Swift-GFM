# Repository quality audit — 2026-11-14

This audit covers the working tree based on commit
`9ed58e9ea60a6fe0060540bbdbd1b477499a0852`, including the local changes that
accompany this report. Its purpose is to describe the evidence and remaining
limits, not to certify every input or platform.

## Findings and changes

1. **Deep AST destruction could overflow the stack.** On Linux x86_64, parsing
   and walking a document with 50,000 nested block quotes succeeded, but
   releasing the former recursively owned Swift tree crashed with `SIGSEGV`.
   The tree now uses immutable flat storage. A regression test parses, walks,
   and releases 50,000 levels; a separate process also completed 100,000. A
   retained node keeps the entire parsed tree's storage alive, and accessing
   `children` creates an array of child values. These are important memory and
   performance characteristics. Optional input-byte and Swift AST node and
   depth guards have since been added; they do not impose hard C resource bounds.
2. **Documentation mixed current decisions with historical proposals.** The
   README now includes package installation, the documentation has a current
   index, and the upstream strategy and feasibility report identify which
   material is current and which is historical. The wrapper and AST guides now
   describe XML and node-ownership limitations more explicitly.
3. **Local Markdown links had no automated check.** A standard-library Python
   check now validates local Markdown link and image targets outside fenced
   code; CI invokes it on both platforms. It does not validate external URLs,
   HTML links, or document fragments. DocC separately validates its own links.

## Checks performed

- A clean export of the committed baseline and a separate clean copy of the
  audited working tree built and passed the Swift suite on Linux with Swift
  6.4.2. An independent SwiftPM consumer also built and ran against the audited
  working tree using only the public product. A separate consumer resolved the
  private GitHub package at committed revision `9ed58e9ea60a6fe0060540bbdbd1b477499a0852`
  and rendered successfully; that remote revision predates the local audit fix.
- The audited working tree passed debug and release Swift tests, Thread
  Sanitizer, and Address Sanitizer on Linux. The suite includes 746 exact
  bundled HTML comparisons, 704 CommonMark round-trip cases, 2,125 entity
  cases, and the deep AST regression. Two upstream-disabled examples and one
  `<IGNORE>` case remain explicitly skipped. Address Sanitizer leak detection
  was disabled; that run does not test for leaks.
- An independently built pinned cmark-gfm executable matched 4,482/4,482
  source-enabled fixture and rendering-format comparisons. The XML-visible AST
  projection matched 670/670 examples with per-example flags and 670/670 with
  all five GFM extensions enabled. These checks do not prove equivalence for all
  possible inputs or C-only node metadata.
- DocC built with warnings treated as errors and 140/140 source-declared public
  symbols had documentation. The package also built with complete strict
  concurrency checking and Swift warnings treated as errors. Strict
  `swift-format` lint, Python tooling tests, fixture and vendor hash checks,
  the C symbol namespace audit, 13 CLI checks, and local Markdown link checks
  passed. The test totals can be reproduced with the commands in
  [REPRODUCTION.md](REPRODUCTION.md).

## Licensing decision and remaining limits

- The project owner selected Apache License 2.0 for SwiftGFM's original code.
  The root `LICENSE` and `NOTICE` identify that decision and the separate
  upstream C and fixture notices.
- The [last committed CI run](https://github.com/ThorFuchs/Swift-GFM/actions/runs/43593767000)
  passed Linux x86_64 and macOS arm64 with Swift 6.4.2. At audit time, the new
  local AST storage change had not yet been run on macOS, so that earlier result
  is not evidence for it. Check the [latest CI runs](https://github.com/ThorFuchs/Swift-GFM/actions/workflows/ci.yml)
  for subsequent commits. The macOS job does not run the Linux-only C-reference
  or sanitizer checks.
- The optional [resource limits](RESOURCE-LIMITS.md) bound input bytes and
  Swift AST projection, but cannot enforce hard C memory, output-size, or
  execution-time limits. A running C call is not cancellable. Raw HTML and link
  policies are not a general sanitizer. See [SECURITY-MODEL.md](SECURITY-MODEL.md).
- The pinned backend's XML can be malformed for some inputs, and five
  CommonMark-to-HTML round trips differ in bytes from their source fixture,
  including two with changed inline-code spaces. See [WRAPPER-API.md](WRAPPER-API.md)
  and [BUNDLED-CMARK-QA.md](BUNDLED-CMARK-QA.md).
- There is no claim of complete published-specification, GitHub.com, or Jekyll
  conformance. Repository history contains both current documentation and
  labeled historical research; see the [documentation index](README.md).
