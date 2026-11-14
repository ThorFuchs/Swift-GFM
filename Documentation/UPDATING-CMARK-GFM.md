# Updating the vendored cmark-gfm

SwiftGFM vendors an unmodified copy of [github/cmark-gfm](https://github.com/github/cmark-gfm).
`Vendor/GitHubCMark/UPSTREAM_SHA256.json` records the pinned revision and the
hash of every vendored file, and is the single source of truth for the revision
used by the tools, the reference build script, and CI.

## When to update

- Watch upstream's [releases](https://github.com/github/cmark-gfm/releases),
  [security advisories](https://github.com/github/cmark-gfm/security/advisories),
  and default branch. `git ls-remote https://github.com/github/cmark-gfm.git HEAD`
  shows the current upstream head.
- Security fixes take priority and may ship as a patch release. Any other
  backend update is at least a minor release because output can change, and a
  major release if it requires new `MarkdownNodeKind` cases. See the
  [versioning policy](../README.md#versioning-and-api-stability).

## Steps

1. **Check out the new revision** in a clean directory:

   ```sh
   git init upstream && cd upstream
   git remote add origin https://github.com/github/cmark-gfm.git
   git fetch --depth 1 origin NEW_REVISION && git checkout --detach FETCH_HEAD
   cd ..
   ```

2. **Copy the sources and rewrite the manifest:**

   ```sh
   python3 Tools/vendor_cmark_gfm.py upstream
   ```

   This replaces `src/`, `extensions/`, and `COPYING`, renders
   `generated/cmark-gfm_version.h`, and writes `UPSTREAM_SHA256.json`. Review
   the upstream diff (`git diff Vendor`) before continuing. If upstream adds or
   removes source files, also update the `exclude:` list of the `GitHubCMark`
   target in `Package.swift`. If upstream changes CMake configuration, compare
   `generated/config.h` and `generated/cmark-gfm_export.h` with a CMake build.

3. **Update the test fixtures.** Copy the upstream `test/*.txt` files listed in
   [the fixture README](../Tests/SwiftGFMTests/Fixtures/cmark-gfm/README.md)
   byte for byte, then update their hashes and example counts in the README and
   in `SOURCES` in `Tools/bundled_cmark_fixtures.py`. Regenerate the entity
   fixture from a reference build at the new revision:

   ```sh
   sh Tools/build-references.sh "$PWD/.references"
   python3 Tools/generate_cmark_entity_fixture.py --reference "$PWD/.references/cmark-gfm-build/src/cmark-gfm"
   ```

4. **Update literal mentions.** `python3 Tools/check_backend_revision.py` lists
   every file that still names the old revision or version, including
   `MarkdownEngine.backendRevision`, the README, `NOTICE`, and the test that
   checks `MarkdownEngine.backendVersion`.

5. **Update the symbol namespace.** On Linux, build and run
   `Tools/check_cmark_symbol_namespace.py` (see [TESTING.md](TESTING.md)). Add any
   newly reported C global to the `cmarkSymbols` list in `Package.swift`.

6. **Handle new node kinds.** If upstream adds node types, `parse(_:)` throws
   `unsupportedASTNode` for them. Add `MarkdownNodeKind` cases and their
   conversion; this makes the update a major release.

7. **Run every check** in [TESTING.md](TESTING.md), including the comparison
   with the upstream executable. Record any new skips or round-trip
   differences in [BUNDLED-CMARK-QA.md](BUNDLED-CMARK-QA.md).

8. **Add a changelog entry** naming the old and new revisions, upstream
   security fixes, and any output changes users should expect.
