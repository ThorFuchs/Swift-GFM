# Testing and verification

SwiftGFM's compatibility contract is fidelity to the pinned GitHub cmark-gfm
backend. The checks below establish that fidelity and the package's own
behavior. CI runs all of them; see [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)
for the exact jobs and toolchains.

## Everyday checks

These need only a Swift toolchain and Python 3 (standard library only):

```sh
swift test
swift test -c release
swift format lint --strict --recursive Sources/SwiftGFM Sources/swift-gfm Tests/SwiftGFMTests
python3 -m unittest discover -s Tools -p 'test_*.py'
python3 Tools/check_documentation_links.py
python3 Tools/check_backend_revision.py
```

`swift test` runs the pinned backend's bundled fixtures, the derived
named-entity fixture, CommonMark round trips, AST, resource-limit, and
concurrency tests. It needs no network access or reference executable. See
[bundled test coverage](BUNDLED-CMARK-QA.md) for the corpus, its explicit skips,
and the documented round-trip differences.

The Python tests verify fixture and vendored-source hashes, license notices,
the C symbol namespace mapping, and the tools themselves.

## Sanitizers

```sh
swift test --sanitize=thread
ASAN_OPTIONS=detect_leaks=0 swift test --sanitize=address
```

CI runs Thread Sanitizer on Linux and macOS and Address Sanitizer on Linux.
Leak detection is disabled for the Address Sanitizer run, so it is not a leak
check.

## API documentation

```sh
sh Tools/build-docc.sh
```

The script needs `docc` on `PATH` (on macOS, add the directory printed by
`dirname "$(xcrun --find docc)"`). It extracts the public symbol graph, fails if
any source-declared public symbol is undocumented, and builds
`.build/SwiftGFM.doccarchive` with warnings treated as errors.

## Comparison with the upstream C executable

These checks compare SwiftGFM with an independently built cmark-gfm at the
pinned revision. They need git, CMake, and a C compiler:

```sh
sh Tools/build-references.sh "$PWD/.references"
swift build
reference="$PWD/.references/cmark-gfm-build/src/cmark-gfm"
swift_gfm="$(swift build --show-bin-path)/swift-gfm"
python3 Tools/check_bundled_fixture_extraction.py --upstream-test-dir "$PWD/.references/cmark-gfm/test"
python3 Tools/generate_cmark_entity_fixture.py --reference "$reference" --check
python3 Tools/check_cli_behavior.py --binary "$swift_gfm"
python3 Tools/check_bundled_cmark_reference.py --probe "$swift_gfm" --reference "$reference" \
  --report Artifacts/bundled-backend-parity.json
python3 .references/cmark-gfm/test/pathological_tests.py --program "$swift_gfm html"
```

- **Fixture extraction** checks that SwiftGFM's fixture parser yields exactly
  the cases that upstream's own `get_tests` yields.
- **Entity fixture** regenerates the expected HTML for all 2,125 named entities
  and compares it with the checked-in file.
- **Backend parity** renders every source-enabled fixture input in all six
  formats with both executables and compares raw bytes (4,482 comparisons).
- **Pathological inputs** run upstream's adversarial timing suite against the
  SwiftGFM CLI.

CI additionally runs upstream's `spec_tests.py --no-normalize` against the CLI
for the spec, extension, regression, and smart-punctuation suites.

Reports are written to the ignored `Artifacts/` directory. The scripts record
the reference executable's hash, but cannot prove from the binary which
revision it was built from; `build-references.sh` checks out and verifies the
pinned commit.

## AST projection

[`Tools/ASTParityProbe`](../Tools/ASTParityProbe) is a small executable that
prints SwiftGFM's public AST as JSON. The check compares it with the reference
executable's XML for every upstream-enabled spec example, once with each
example's own extensions and once with all five GFM extensions:

```sh
swift build --package-path Tools/ASTParityProbe
probe="$(swift build --package-path Tools/ASTParityProbe --show-bin-path)/ASTParityProbe"
python3 Tools/check_ast_projection.py --probe "$probe" --reference "$reference" \
  --report Artifacts/ast-fixture-flags.json
python3 Tools/check_ast_projection.py --full-gfm --probe "$probe" --reference "$reference" \
  --report Artifacts/ast-full-gfm.json
```

The comparison covers node kinds, nesting, literals, XML attributes, and source
positions. C-only fields that the XML does not serialize are covered by focused
Swift tests instead; see [AST.md](AST.md).

## C symbol namespace

The vendored C globals are renamed with a `swiftgfm_` prefix at compile time so
that SwiftGFM can be linked next to other cmark copies, such as the one used by
Swift Markdown. After a Linux build, check the combined object:

```sh
python3 Tools/check_cmark_symbol_namespace.py "$(find .build -name GitHubCMark.o -type f -print -quit)"
```

## What these checks do not establish

The checks are evidence for the tested inputs, configurations, and platforms.
They do not certify conformance to the published CommonMark or GFM
specifications, equivalence with GitHub.com's hosted renderer, freedom from
data races in all interleavings, or bounded resource use for arbitrary input.
