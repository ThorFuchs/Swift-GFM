# Can Swift Markdown's AST represent the remaining GFM failures?

This compares the 136 enabled failures from the newer bundled cmark-gfm suite that were outside the two HTML-difference clusters selected for exclusion (`same_html5_fragment_tree` and `structural_layout_whitespace_only`). The excluded 53 remain strict HTML failures; the exclusion is for this investigation, not a claim that structural whitespace is always cosmetic. The two source-disabled examples are also outside this denominator. See [failure clusters](GFM-FAILURE-CLUSTERS.md) for scope.

## Result

| HTML evidence group | Selected | Comparable AST projection matches | Projection differences | Inconclusive |
| --- | ---: | ---: | ---: | ---: |
| Link signature differs | 55 | 44 | 11 | 0 |
| Image signature differs | 22 | 22 | 0 | 0 |
| Element inventory differs | 57 | 57 | 0 | 0 |
| Other attribute inventory differs | 2 | 2 | 0 | 0 |
| **Total** | **136** | **125** | **11** | **0** |

**A projection match is not certification that the whole Swift AST is correct or sufficient.** The reference is cmark-gfm at `27d942c8b0a62d192f616e5bf3578f4b6a89e180`, not an independently specified expected AST. The comparison covers node kind, nesting, text, link/image destination and title, list type/start, heading level, code and HTML literals. Original source positions and syntax spelling are excluded; empty link/image attributes are normalized to absent, and adjacent text nodes are merged. Different node types or process/XML errors would be explicitly inconclusive. The JSON report retains both full projections and command outputs, and the Markdown companion lists every case.

* The **11 observed projection differences** are all the source's autolink-extension cases 621–631. The reference attaches the `autolink` extension for those cases and produces link nodes; the tested Swift Markdown parser does not attach it and produces plain text instead. These are concrete differences under the two tested configurations, not evidence that Swift Markdown's parser is intrinsically unable to represent a link.
* In **47 of the 125 matches**, the reference contains list tightness metadata that Swift Markdown's public list model does not retain. Our projection necessarily drops that metadata, flags it on each case, and cannot certify those trees are sufficient to reconstruct the reference HTML. Ordered-list delimiter information is also flagged when present. Example 9 shows why tightness affects output: tight list items should not acquire extra paragraph elements.
* In example **652**, the raw-HTML AST projection matches, but the reference fixture requests the `tagfilter` extension. Tag filtering is applied during HTML rendering; a matching raw tree does not establish that the filter was applied or that the resulting HTML meets the fixture.
* In example **161**, both projected trees preserve the link title; Swift's tested HTML formatter omits it. In **525**, both contain the image text `moon`; the formatter emits no `alt` attribute. Those cases support a renderer diagnosis for those specific outputs.
* Example **512** has matching link destination data in the compared projection, yet Swift's formatted HTML has an improperly quoted destination. A matching tree does not make its formatter output safe or correct.

The remaining 78 projection matches without a flagged list field are still **partial evidence only**: they do not establish correctness of source ranges, original syntax, omitted distinctions, all possible inputs or the behavior of transformations. They also do not turn their strict HTML failures into passes. Different parser configurations matter for every case: Swift Markdown always enables tables, strikethrough and task lists, while the C reference receives the original fixture's flags. For full confidence in a strict profile, compare against a profile-matched reference, preserve required metadata, and add direct regression tests, rather than treating these counts as a universal trust guarantee.

For the historical bundled suite, the same method selected 129 cases: 116 partial projection matches, 13 differences, 0 inconclusive. Eleven differences are autolink cases. The other two are raw-HTML comment examples 645 and 646, where the historical cmark reference and the tested Swift Markdown parser produce different node structures; this comparison alone does not decide which behavior is normative for a selected version.

## Method and reproducibility

`Experiments/MarkdownProbe` exposes a diagnostic `ast-json` mode using Swift Markdown's public nodes and attributes. The C reference is run on the same fixture input and its source-specified extension flags with `--to xml`. The analysis maps both outputs to a narrow common representation; it does not attempt a full AST conversion. Because the cmark XML renderer writes literal newlines and tabs in some XML attributes, those literal characters are converted to numeric character references before XML parsing; otherwise the XML parser normalizes them to spaces and can invent a difference in multiline link titles. Tests cover this case.

The reference executable hash must match the paired HTML comparison. The Swift probe was rebuilt to add `ast-json`, so each selected example's `html` output was rerun and required to match the paired report before its AST result was accepted. Binary hashes, fixture/report hashes, commands and raw output are stored in the JSON. This HTML recheck does not authenticate the source revision of a binary; builds and lockfiles remain part of the provenance.

After generating the paired reports and HTML clusters as described in their guides, run:

```sh
python3 Tools/compare_gfm_ast.py --clusters Artifacts/swift-markdown-gfm-current-clusters.json --paired Artifacts/swift-markdown-gfm-current-bundled.json --swift-markdown "$PWD/Experiments/MarkdownProbe/.build/debug/markdown-probe" --reference "$PWD/.references/cmark-gfm-build/src/cmark-gfm" --output Artifacts/gfm-current-ast-comparison.json
python3 Tools/compare_gfm_ast.py --clusters Artifacts/swift-markdown-gfm-historical-clusters.json --paired Artifacts/swift-markdown-gfm-historical-bundled.json --swift-markdown "$PWD/Experiments/MarkdownProbe/.build/debug/markdown-probe" --reference "$PWD/.references/cmark-gfm-2019-build/src/cmark-gfm" --output Artifacts/gfm-historical-ast-comparison.json
```

A nonzero exit means at least one projection differs or was inconclusive; it is not a release-gate decision. Per-case projection diffs are supplementary to, and do not replace, the original HTML diffs.
