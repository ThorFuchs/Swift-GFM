# The 15 unmatched published GFM examples

Investigation date: 2026-11-13. Recommendation: **retain all 15 in the 677-example published corpus**. An absent or disabled historical match is provenance information, not evidence that a published example can be discarded. Do not count a skipped example as passing, and do not adjust its input or expected HTML to make a reference pass.

## Evidence and limits

The published [GFM 0.29-gfm page](https://github.github.com/gfm/) is pinned in `Fixtures/gfm/spec.html` by SHA-256. Its examples are extracted from the displayed HTML, including the specification's documented convention that `→` denotes a tab. The original source used to produce this precise page has not been identified, so the extraction still requires independent source verification. Historical source evidence is `test/spec.txt` from [cmark-gfm 0.29.0.gfm.0](https://github.com/github/cmark-gfm/blob/b8eb2e00de094999f978e9cb02b1a78d810812d3/test/spec.txt), not an assertion that the published page was generated from that revision. That file is also pinned in this repository.

Of the 15, **two** (279 and 280) match the historical source exactly but are marked `example disabled` there. The other **13** have no exact input-and-output match in that source. The historical source and the published page have differences despite both identifying their specification as 0.29; this establishes divergence between the two checked snapshots, not when or why it occurred. Several published examples differ from old examples only by whitespace or additional content; similarity does not make them identical fixtures.

The reference observations below use independently built cmark-gfm `b8eb2e00de094999f978e9cb02b1a78d810812d3` (2019) and `27d942c8b0a62d192f616e5bf3578f4b6a89e180` (current snapshot). Both ran with `--unsafe`; the diagnostic enabled the individual named extension shown in the table, or none for the base examples. These are **per-example investigative settings**, not a global GFM profile. Both binaries completed all 15 comparisons. The historical binary matched 9/15 exactly; the newer binary matched 10/15. A match supports the displayed expectation but is not independent verification of the extraction.

| Published example | Behavior and historical-source finding | 2019 / current reference | Reporting treatment |
| --- | --- | --- | --- |
| [83](https://github.github.com/gfm/#example-83) | Indented continuation of a paragraph; historical near-match has an additional final blank line. | pass / pass | Keep the published bytes; run as a base-syntax example. |
| [87](https://github.github.com/gfm/#example-87) | Leading/trailing blank lines around indented code; near-match has an additional final blank line. | pass / pass | Keep the published bytes; run as a base-syntax example. |
| [279](https://github.github.com/gfm/#example-279) | Unchecked and checked task items; exact historical match is explicitly disabled. | fail / fail | Keep. Task-list semantics appear in the output, but checkbox attribute order and self-closing serialization differ from the published HTML. Record strict HTML failure separately from any independently verified semantic match. |
| [280](https://github.github.com/gfm/#example-280) | Nested task items; exact historical match is explicitly disabled. | fail / fail | Keep; same serialization issue as 279. Test nesting and checkbox states independently as well as raw HTML. |
| [324](https://github.github.com/gfm/#example-324) | Eight-digit decimal reference `&#87654321;` is displayed as a nonentity. Historical near-match uses nine digits. The published prose specifies 1–7 decimal digits. | fail / fail | Keep as a parser discrepancy. Both references produce U+FFFD; current cmark-gfm source accepts up to eight digits (`src/houdini_html_u.c`). Do not normalize this difference away. |
| [491](https://github.github.com/gfm/#example-491) | One- and two-tilde strikethrough; historical near-match covers only the double-tilde form. | pass / pass | Keep; use strikethrough for reference diagnostics. |
| [493](https://github.github.com/gfm/#example-493) | Three tildes do not produce inline strikethrough; no exact old match. | pass / pass | Keep; use strikethrough for reference diagnostics. |
| [544](https://github.github.com/gfm/#example-544) | Link-label emphasis boundary; the old near-match lacks the trailing `*`. | pass / pass | Keep; base-syntax diagnostic. |
| [549](https://github.github.com/gfm/#example-549) | Reference-label Unicode case folding, `ẞ` matched to `SS`; no exact old match. | pass / pass | Keep; base-syntax diagnostic. |
| [625](https://github.github.com/gfm/#example-625) | Extended autolink parentheses; historical near-match contains fewer input paragraphs. | pass / pass | Keep; use autolink for reference diagnostics. The later inspected cmark-gfm source contains an exact enabled match. |
| [629](https://github.github.com/gfm/#example-629) | Extended HTTP/HTTPS links; historical near-match adds an FTP example. | pass / pass | Keep; use autolink for reference diagnostics. |
| [633](https://github.github.com/gfm/#example-633) | `mailto:` and `xmpp:` protocol links; no exact old match. | fail / pass | Keep; historical parser links the email portion rather than the whole protocol URL; newer reference matches this example. |
| [634](https://github.github.com/gfm/#example-634) | XMPP resources containing `@`; no exact old match. | fail / fail | Keep as a parsing/link-boundary discrepancy. Historical reference links the email only; current reference handles the first line but mislinks resource lines containing `@`. |
| [635](https://github.github.com/gfm/#example-635) | Only the first XMPP resource segment belongs in the link; no exact old match. | fail / fail | Keep as a parsing/link-boundary discrepancy. Current reference includes `/bin` in the URL. |
| [665](https://github.github.com/gfm/#example-665) | Spaces at a line break inside a code span; historical near-match has one rather than two trailing spaces. | pass / pass | Keep the exact spaces. The later inspected cmark-gfm source contains an exact enabled match. |

For examples 279 and 280, HTML permits different attribute order and equivalent void-element spelling. The specification prose leaves checkbox interaction behavior open; that does not make the raw HTML identical, nor does this diagnostic establish a complete semantic comparison. For the strict exact-output contract, preserve the original expected bytes and report an HTML serialization mismatch. A separate, explicitly labeled semantic or AST check can establish whether the recognized list and checked states match.

## Crucial corpus-scoping issue

The published document contains **both base-syntax examples and extension examples**. A reference run that turns on every GFM extension for every example is not the same experiment as the source's per-example extension runs. For example, [620](https://github.github.com/gfm/#example-620) expects a bare HTTP URL to remain text, while the [extended-autolink section](https://github.github.com/gfm/#autolinks-extension-) describes linking such URLs; [140](https://github.github.com/gfm/#example-140) preserves a script tag while the [tagfilter extension](https://github.github.com/gfm/#disallowed-raw-html-extension-) filters that tag. The historical source records extension labels on some examples. It follows that 100% exact matches across all displayed examples under one fixed, fully enabled renderer is not currently a defensible release gate without an explicit interpretation of those examples and additional evidence.

Keep two visible measurements:

1. **Published example comparison:** all 677 IDs, original inputs and HTML, exact comparison; each case records the execution configuration and provenance. Until extraction and all configurations are validated, mark the overall result **incomplete**, with counts of passes, failures, and skips. A skip fails the proposed zero-skip gate.
2. **Fixed `.gfm` profile comparison:** run the same implementation and profile settings across a separately documented, justified corpus of GFM-active examples and additional interaction cases. This must not be labeled a full 677-example pass. Display strict byte differences and separately classified parser/renderer evidence.

Historical reference runs, diagnostic normalization, and semantic equivalence checks are supporting evidence, never replacements for the original expected output. The present work supplies no basis for declaring any of the 15 obsolete or excluded. The complete example configurations and exact original source for the published page remain open; task-list serialization and the 324/634/635 disagreements need resolution in the candidate implementation.

## Reproduce

Build the pinned binaries using `Tools/build-references.sh`, then:

```sh
python3 Tools/investigate_gfm_15.py \\
  --historical "$PWD/.references/cmark-gfm-2019-build/src/cmark-gfm" \\
  --current "$PWD/.references/cmark-gfm-build/src/cmark-gfm" \\
  --report Artifacts/gfm-15-investigation.json
```

The JSON contains each original extracted input, expected output, exact command, actual output, stderr, and exit status. The program labels requested revisions but does not authenticate the supplied executables. The historical map report now distinguishes an exact disabled source example from one with no exact match. See [REPRODUCTION.md](REPRODUCTION.md) for build and checksum details.
