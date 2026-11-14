# Contributing to Swift-GFM

Start with a small, reproducible problem or a focused proposal. Use
[Issues](https://github.com/ThorFuchs/Swift-GFM/issues) to discuss behavior and
open a pull request against `main` when the change is ready to review. The
project is maintained by [Thorsten Fuchs](https://github.com/ThorFuchs).

## Scope

SwiftGFM's contract is fidelity to the pinned GitHub cmark-gfm backend. A
rendering difference from GitHub.com, Jekyll, or the published specifications
is in scope only if the pinned upstream executable behaves differently from
SwiftGFM. Behavior changes in the C library belong upstream in
[github/cmark-gfm](https://github.com/github/cmark-gfm). Never edit files under
`Vendor/GitHubCMark/src` or `Vendor/GitHubCMark/extensions`; update the whole
backend as described in [updating cmark-gfm](Documentation/UPDATING-CMARK-GFM.md).

Keep one `SwiftGFM` library, one `swift-gfm` executable, and an empty
dependency graph.

## Set up

Use Swift 6.0 or newer. No other dependency is needed for the library, CLI, or
tests. The upstream comparison checks also need git, CMake, a C compiler, and
Python 3.

## Make a change

- Write Swift Testing regressions through the public API, with the smallest
  input that shows the problem.
- Document every public declaration; `sh Tools/build-docc.sh` rejects missing
  documentation and DocC warnings.
- Keep public types `Sendable`, and keep C pointers inside the engine's lock.
- Follow the [versioning policy](README.md#versioning-and-api-stability) and
  add an entry under "Unreleased" in [CHANGELOG.md](CHANGELOG.md) for
  user-visible changes.
- Do not change fixture bytes or expectations to accommodate an implementation
  failure.

## Run the checks

```sh
swift test
swift format lint --strict --recursive Sources/SwiftGFM Sources/swift-gfm Tests/SwiftGFMTests
python3 -m unittest discover -s Tools -p 'test_*.py'
python3 Tools/check_documentation_links.py
python3 Tools/check_backend_revision.py
```

For changes to parsing, rendering, or the AST, also run the comparisons with
the upstream executable in [TESTING.md](Documentation/TESTING.md). In your pull
request, describe the problem, the resulting behavior, the checks you ran with
their results, and any checks you could not run.

## Licensing

Contributions are licensed under the [Apache License 2.0](LICENSE), as stated
in its section 5. Retain third-party notices and record new third-party
material in [NOTICE](NOTICE).

Follow the [community standards](CODE_OF_CONDUCT.md). Report security problems
privately as described in [SECURITY.md](SECURITY.md).
