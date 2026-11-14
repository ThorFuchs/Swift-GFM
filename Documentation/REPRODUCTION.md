# Reproduction and gate status

**Current wrapper:** The main package provides the six-format string-to-string API described in [WRAPPER-API.md](WRAPPER-API.md) and a separate read-only [Swift AST](AST.md). Historical feasibility and specification-gate results below remain evidence rather than a statement that the wrapper is absent.

The published versions checked on 2026-11-13 are [CommonMark 0.31.2](https://spec.commonmark.org/) and [GFM 0.29-gfm](https://github.github.com/gfm/). Their corpora are independent.

* CommonMark: unmodified published JSON `https://spec.commonmark.org/0.31.2/spec.json`, SHA-256 `d431b29d97b6f73e69d547109cf5081578fac931e72afe95639ebe766c1b2a20`. The commonmark-spec release tag resolves to `9103e341a973013013bb1a80e13567007c5cef6f`; exact generation of this JSON from the tag has not been verified. License is adjacent.
* GFM: unmodified published HTML `https://github.github.com/gfm/`, SHA-256 `b153d814fdfc8624bb6da7449162c1cd707a637f7d1c1b636eb44b9cf63fa220`, authored by John MacFarlane and licensed CC BY-SA 4.0, included alongside the original HTML. The published page identifies the specification as 0.29-gfm. `Tools/gfm_fixtures.py` extracts all 677 numbered examples, decodes HTML entities and converts the arrow glyph to a tab as specified by the document. Extraction is a derived representation; it needs independent verification against original source examples, including any ambiguity in the arrow convention. The current cmark-gfm repository's `test/spec.txt` is not identical to the published page and is not substituted for it.

With git, CMake, a C compiler, and Python 3:

```sh
Tools/build-references.sh "$PWD/.references"
python3 -m unittest discover -s Tools -p 'test_*.py'
python3 Tools/conformance.py commonmark --renderer-version 'cmark 0.31.2 eec0eeba6d31189fd828314576494566d539b1e3' --report Artifacts/commonmark.json -- "$PWD/.references/cmark-build/src/cmark" --unsafe
python3 Tools/conformance.py gfm --renderer-version 'cmark-gfm 27d942c8b0a62d192f616e5bf3578f4b6a89e180' --report Artifacts/gfm.json -- "$PWD/.references/cmark-gfm-build/src/cmark-gfm" --unsafe -e table -e strikethrough -e tasklist -e autolink -e tagfilter
```

The last command is an exploratory all-extensions comparison, not a qualified reference configuration for every example: the specification includes base examples and extensions, and this run enables all extensions for every example. `--unsafe` enables the spec's raw HTML rather than cmark's default security filtering. To rerun one case add `--example N` before `--`. The command reads one UTF-8 fixture on stdin and writes HTML to stdout. Reports preserve input, expected and actual output, process errors, exact command, fixture hash, Python and platform versions. Pass the exact renderer revision with `--renderer-version`; it is not verified automatically. Byte comparisons are strict, without normalization. Timeouts and failed launches are failures. Differences remain `unclassified` until investigated. Reports and local reference builds are ignored by git.

At the initial baseline on Debian 13 x86_64 with Swift 6.2.3, CMake 4.4.4, GCC 14.2 and Python 3.12.14, reference builds succeeded; pinned cmark 0.31.2 with `--unsafe` passed 652/652; the exploratory GFM command passed 651/677 with 26 failures, zero skipped. The failures include raw HTML/tag filtering, task-list serialization, autolinks and parsing changes. They are not evidence of Swift-GFM conformance. At that point the initial Swift package passed one Swift test on Linux, while macOS and upstream production integration were unqualified. Swift 6.4.2 was subsequently installed and tested locally; see the toolchain section below.

The original specification-driven S0/S1 gates remain open under the initial briefing. The subsequently approved design wraps the vendored C backend and provides XML and a read-only Swift AST; it does not claim a standards-qualified CommonMark, GFM, or Jekyll profile.

## Swift 6.4.2 on Linux

The local toolchain is at `.toolchains/swift-6.4.2/usr/bin` (ignored by git; approximately 3.5 GB). This is the official Ubuntu 24.04 x86_64 Swift 6.4.2 release archive, used here on Debian 13. Its SHA-256 is `2e9ebec040ad459dd89a6d093a02d8314939135104850fae4d5c0f174fb3ba8c`. Its detached signature verified against the Swift 6.x release signing key retrieved from https://swift.org/keys/all-keys.asc; fingerprint `52BB 7E3D E28A 71BE 22EC 05FF EF80 A866 B47A 981F`. GPG reported the key was not locally certified. Source: https://download.swift.org/swift-6.4.2-release/ubuntu2404/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE-ubuntu24.04.tar.gz.

```sh
export PATH="$PWD/.toolchains/swift-6.4.2/usr/bin:$PATH"
swift --version
swift test -j 4
```

The sandbox used in this session required its network-enabled mode for SwiftPM's wakeup socket; unrestricted connectivity is not a package requirement. Where user-level caches are unwritable, setting `XDG_CACHE_HOME` and `CLANG_MODULE_CACHE_PATH` to writable temporary directories avoids cache failures. The separate swift-markdown probe also built with Swift 6.4.2 at the revisions in the decision record. The package requires Swift tools 6.4.

On 2026-11-14, [GitHub Actions run 43593382912](https://github.com/ThorFuchs/Swift-GFM/actions/runs/43593382912) passed for commit `fe99d63bdcabc5524a6ed55af232ce897a5d34ec`. Linux x86_64 used the pinned official Swift 6.4.2 Ubuntu 24.04 image and completed the reference, DocC, and sanitizer checks. GitHub-hosted macOS arm64 used Xcode 27.2 (build 27B52) and Apple Swift 6.4.2, and passed the debug and release Swift suites and 25 Python tooling tests. The macOS job did not run the Linux-only C-reference comparisons or sanitizers. Address Sanitizer leak detection is disabled; that is not a leak check. This run does not qualify every architecture, backend configuration, resource limit, or formal specification.

## Read-only AST parity

With the pinned reference built by `Tools/build-references.sh`, build the
standalone probe and compare its public AST projection to the C executable's
XML. These commands process every upstream-enabled example twice, with the
fixture's own extension flags and then with all GFM extensions enabled:

```sh
swift build --package-path Experiments/ASTParityProbe
probe="$(swift build --package-path Experiments/ASTParityProbe --show-bin-path)/ASTParityProbe"
python3 Tools/check_ast_projection.py --probe "$probe" \
  --reference "$PWD/.references/cmark-gfm-build/src/cmark-gfm" \
  --report /tmp/swift-gfm-ast-fixture-flags.json
python3 Tools/check_ast_projection.py --full-gfm --probe "$probe" \
  --reference "$PWD/.references/cmark-gfm-build/src/cmark-gfm" \
  --report /tmp/swift-gfm-ast-full-gfm.json
```

The independent reference must actually be checked out and built at
`27d942c8b0a62d192f616e5bf3578f4b6a89e180`; the script records the executable's
hash but cannot establish its provenance from the binary alone. On Linux with
Swift 6.4.2 both comparisons matched 670/670; the source marks examples 279 and
280 disabled. These are XML projection comparisons, not a formal conformance
claim or complete C AST qualification. See [AST.md](AST.md).

## Bundled backend fixtures and DocC

`swift test` reads the checked-in cmark-gfm test resources, including the
derived named-entity reference file. After running `Tools/build-references.sh`
and `swift build`, the pinned upstream runner, fixture extraction, entity
expectations, and all six renderers can be checked independently:

```sh
python3 Tools/check_bundled_fixture_extraction.py --upstream-test-dir "$PWD/.references/cmark-gfm/test"
python3 Tools/generate_cmark_entity_fixture.py --reference "$PWD/.references/cmark-gfm-build/src/cmark-gfm" --check
python3 Tools/check_bundled_cmark_reference.py --probe "$PWD/.build/debug/swift-gfm" \
  --reference "$PWD/.references/cmark-gfm-build/src/cmark-gfm" --report /tmp/swift-gfm-bundled-parity.json
python3 Tools/check_cli_behavior.py --binary "$PWD/.build/debug/swift-gfm"
sh Tools/build-docc.sh
```

The DocC command needs `docc` on `PATH`; it extracts the symbol graph and
builds `.build/SwiftGFM.doccarchive` without a package plugin. Results, exact
fixture skips and round-trip differences are described in
[BUNDLED-CMARK-QA.md](BUNDLED-CMARK-QA.md).

## Historical GFM source cross-check

`Fixtures/gfm/cmark-gfm-0.29.0.gfm.0-spec.txt` is the original cmark-gfm source spec from commit `b8eb2e00de094999f978e9cb02b1a78d810812d3`, SHA-256 `7cea1221ffba48559d8748c8510d3c5bda40487a13667b80e77c14a1505b9821`, licensed CC BY-SA 4.0. It does not entirely match the published HTML. The new optional historical map independently checks extracted input **and** expected HTML against that source, and uses the source's per-example extension labels only for unique enabled matches. It explicitly skips unmatched, ambiguous or disabled examples and exits nonzero if any example is skipped. This is preliminary evidence, not proof that the source settings apply to all published examples.

```sh
python3 Tools/conformance.py gfm --gfm-historical-extension-map --renderer-version 'cmark-gfm 27d942c8b0a62d192f616e5bf3578f4b6a89e180' --report Artifacts/gfm-historical-map.json -- "$PWD/.references/cmark-gfm-build/src/cmark-gfm" --unsafe
```

At the pinned reference revision this maps 662/677 examples: 651 pass, 11 fail, 15 are skipped with reasons. The 11 include nested emphasis and HTML comment differences. The 15 unmatched include the published task-list examples and other changed examples. These outcomes require investigation, not fixture edits or blanket profile changes. The all-extension comparison remains useful as a separate diagnostic.

For an additional historical reference comparison, the same build script also builds cmark-gfm 0.29.0.gfm.0 at `b8eb2e00de094999f978e9cb02b1a78d810812d3`. CMake 4 requires its minimum-policy override, which the script supplies.

```sh
python3 Tools/conformance.py gfm --gfm-historical-extension-map --renderer-version 'cmark-gfm 0.29.0.gfm.0 b8eb2e00de094999f978e9cb02b1a78d810812d3' --report Artifacts/gfm-2019-map.json -- "$PWD/.references/cmark-gfm-2019-build/src/cmark-gfm" --unsafe
```

On Linux, that historical binary passed all 662 mapped examples, with 0 failures and the same 15 explicit skips. No conclusion is drawn about those unverified examples.

## Upstream cmark-gfm's bundled suites

The upstream reference is written in C. On 2026-11-13, its own test runner was run on Linux with `--no-normalize` against each reference build and the `test/spec.txt` from the *same* checkout:

```sh
cd .references/cmark-gfm-2019
python3 test/spec_tests.py --no-normalize --spec test/spec.txt --program ../cmark-gfm-2019-build/src/cmark-gfm
cd ../cmark-gfm
python3 test/spec_tests.py --no-normalize --spec test/spec.txt --program ../cmark-gfm-build/src/cmark-gfm
```

The historical revision `b8eb2e00de094999f978e9cb02b1a78d810812d3` printed **671 passed, 0 failed, 0 errored, 0 skipped**; its source contains 673 example openings, including two marked `disabled`. The current snapshot `27d942c8b0a62d192f616e5bf3578f4b6a89e180` printed **670 passed, 0 failed, 0 errored, 0 skipped**; its source contains 672 example openings, including two marked `disabled`. The upstream runner filters disabled cases before calculating its printed skip count, so its zero skipped does **not** include those disabled examples. It enables extensions per source example and adds `--unsafe`. `--no-normalize` disables HTML normalization, though the runner still normalizes CRLF to LF. These suites are not identical to the 677 extracted published examples and do not prove a full published-corpus or fixed-profile pass.

## Current wrapper parity and namespace checks

With Swift 6.4.2, CMake, a C compiler, and Python 3:

```sh
Tools/build-references.sh "$PWD/.references"
swift test -j 4
swift test --sanitize=thread -j 4
python3 Tools/compare_github_cmark_probe.py --probe "$PWD/.build/debug/swift-gfm" --reference "$PWD/.references/cmark-gfm-build/src/cmark-gfm" --report Artifacts/swift-gfm-reference-six-formats.json
python3 Tools/check_github_cmark_options.py --valid-utf8-only --probe "$PWD/.build/debug/swift-gfm" --reference "$PWD/.references/cmark-gfm-build/src/cmark-gfm" --report Artifacts/swift-gfm-reference-options.json
swift run --package-path Experiments/CoexistenceProbe -j 4 CoexistenceProbe
```

On Linux with this SwiftPM build layout, the combined C object can be inspected with `python3 Tools/check_cmark_symbol_namespace.py /path/to/GitHubCMark.o`. Find the actual object in the build directory; layout may vary. The current check covers 278 renamed upstream globals plus three prefixed SwiftGFM bridge helpers. Source integrity is covered by `Tools/test_github_cmark_vendor.py` against the pinned source manifest; to verify against the fetched checkout, compare `Vendor/GitHubCMark/src` and `extensions` to the corresponding paths in `.references/cmark-gfm`. See [WRAPPER-API.md](WRAPPER-API.md) for exact results and limitations.
