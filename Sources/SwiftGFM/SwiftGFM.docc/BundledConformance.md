# Bundled upstream conformance tests

Understand the scope of the pinned cmark-gfm fixture comparisons.

The Swift test target includes unmodified fixture files from GitHub cmark-gfm
revision `27d942c8b0a62d192f616e5bf3578f4b6a89e180`. It exercises the bundled
specification, extensions, regression, smart-punctuation, full-info-string, and
table-style examples with the
configuration used by the upstream test runner. Expected and actual HTML are
compared as UTF-8 bytes; the harness does not normalize HTML or line endings.
The specification, extension, and option-specific suites also check the
CommonMark-to-HTML round trip; the harness removes the upstream writer's
synthetic end-list comment first. Five specification cases differ from the
fixture's expected HTML after a round trip. Their exact independently captured
cmark outputs are tested separately; see the repository's conformance guide.

Two specification examples are marked disabled upstream. One extensions example
has `<IGNORE>` rather than expected HTML. These appear as explicitly skipped
tests, with reasons. The source fixture files, provenance, and hashes remain in
the test resources.

The tests also compare all 2,125 names in the backend's entity table against
exact HTML from the pinned C executable. Those derived expectations have a
reproducible generator and are distinct from the unmodified upstream files.

These fixture comparisons qualify the pinned backend and selected wrapper
configuration on the examples run. They are distinct from a claim of universal
CommonMark, GFM specification, Jekyll, or GitHub.com hosted-renderer conformance.
