# Swift Markdown against cmark-gfm's bundled suites

On Linux x86_64 with Swift 6.4.2, compared the official swift-markdown revision `ea1d88be47afe8a731b3971d7b3fb7a3a6db1a5a`, with swift-cmark `437611671145d47e6d9679761b8a5987766f4ae5`, to the unmodified `test/spec.txt` bundled with two pinned github/cmark-gfm revisions. `MarkdownProbe` uses `Document(parsing:options: .disableSmartOpts)` and `HTMLFormatter` defaults. These are combined parser-and-renderer results, not isolated parser diagnoses.

| Source spec / corresponding C reference | Enabled examples | Swift Markdown exact matches | Swift Markdown mismatches | C reference exact matches | Source-disabled examples |
| --- | ---: | ---: | ---: | ---: | ---: |
| cmark-gfm 0.29.0.gfm.0 `b8eb2e00de094999f978e9cb02b1a78d810812d3` | 671 | 489 | 182 | 671 | 2 |
| cmark-gfm 0.29.0.gfm.13 snapshot `27d942c8b0a62d192f616e5bf3578f4b6a89e180` | 670 | 481 | 189 | 670 | 2 |

No enabled cases were skipped. Each of the two disabled task-list examples was also run against Swift Markdown as a supplementary diagnostic and differed; the C reference was not run against those disabled cases. The totals above match the examples enabled by upstream's own test runner; its displayed "0 skipped" does not count the two cases filtered before execution.

Each reference invocation uses `--unsafe` and the exact source fixture's extension labels, matching upstream runner intent. Swift Markdown's public parser instead always attaches tables, strikethrough and task lists, and does not offer per-example extension selection. Thus **the parser configurations are not identical**, especially for base examples, autolink and tagfilter examples. The results accurately report exact HTML from the tested Swift Markdown invocation; a failure does not by itself locate the cause in parsing rather than serialization, or establish whether a different hypothetical configuration would pass. Its formatter can also produce semantically equivalent but byte-different HTML. No normalization is used in this comparison, including CRLF; the upstream runner's `--no-normalize` still normalizes CRLF to LF.

For the current suite's enabled cases, the source labels and Swift output results are:

| Source flags | Swift matches | Swift differences |
| --- | ---: | ---: |
| No extension flag | 471 | 177 |
| table | 8 | 0 |
| strikethrough | 2 | 0 |
| autolink | 0 | 11 |
| tagfilter | 0 | 1 |

The lack of an extension flag in an upstream example means the C reference is invoked without that extension; it does not mean Swift Markdown turns off its own always-attached extensions. The autolink and tagfilter cases are concrete GFM differences: in source example 621, `www.commonmark.org` remains plain text instead of becoming a link; in source example 652, disallowed tags remain unfiltered. The 177 cases without an extension flag include rendering as well as parsing or configuration differences and must not be counted as 177 distinct parser bugs.

Fixture extraction was independently checked against the upstream runner's `--dump-tests` output: all enabled fixture IDs, Markdown inputs, expected HTML and flags match (671/671 historical and 670/670 current). The two source-disabled cases remain visible in our reports. The two bundled suites differ from the 677 examples extracted from the published GFM page and are not a complete qualification of a fixed GFM profile.

## Reproduce

Build references with `Tools/build-references.sh "$PWD/.references"`; build `Experiments/MarkdownProbe` using Swift 6.4.2 and its `Package.resolved`. Then run:

```sh
python3 Tools/compare_bundled_gfm.py historical --swift-markdown "$PWD/Experiments/MarkdownProbe/.build/debug/markdown-probe" --reference "$PWD/.references/cmark-gfm-2019-build/src/cmark-gfm" --report Artifacts/swift-markdown-gfm-historical-bundled.json
python3 Tools/compare_bundled_gfm.py current --swift-markdown "$PWD/Experiments/MarkdownProbe/.build/debug/markdown-probe" --reference "$PWD/.references/cmark-gfm-build/src/cmark-gfm" --report Artifacts/swift-markdown-gfm-current-bundled.json
```

The command exits nonzero when an enabled comparison fails. JSON and text reports preserve each input, expected output, exact actual output, flag, reference and Swift command, output errors, fixture source and revision, and binary hashes. Binary hashes record what was executed but do not themselves prove the asserted source revisions.
