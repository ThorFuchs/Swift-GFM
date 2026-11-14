# Swift Markdown versus bundled GFM: failure clusters

This is a secondary investigation of **strict byte failures**, not a new pass criterion. The principal comparison is the [newer bundled cmark-gfm suite](SWIFT-MARKDOWN-BUNDLED-GFM.md): 481/670 enabled examples matched, 189 differed, and 0 enabled examples were skipped. The two source-disabled cases are not included in the clustering denominator; their outputs remain in the original paired report. Historical-suite analysis covers its 182 enabled failures separately.

The compared Swift Markdown command uses `Document(parsing:options: .disableSmartOpts)` and `HTMLFormatter`; the reference receives extension flags from each upstream example. Swift Markdown cannot select those same per-example flags. Counts therefore describe the tested invocation against fixture expectations, not a matched-configuration experiment or proof that all differences are parser bugs.

## Current suite: mutually exclusive primary clusters

| Primary evidence group | Cases | Interpretation |
| --- | ---: | --- |
| Same HTML5 fragment tree | 22 | In an HTML5 parser's default fragment context, the parsed trees, attributes and text agree. Differences include entity spelling such as `&quot;` versus a literal quote. One case reports an HTML5 parse error during recovery, leaving 21 without reported parse errors on either side. These remain exact-output failures. |
| Structural layout whitespace only | 31 | Trees match after a narrow rule removes newline-containing, ASCII whitespace-only nodes between block children of specified structural containers. This can matter under some CSS or embedding contexts; it is not a universal semantic-equivalence claim. |
| Link signature differs | 55 | Link count, destination, title and/or link text differ. This includes all 11 upstream autolink-extension examples. Some URL spellings might still denote the same destination; inspect each case. |
| Image signature differs | 22 | Image source, alternative text, title or count differ. In these 22 cases an expected image has an `alt` attribute, while no actual image in the corresponding output has one; this can affect accessibility. |
| Element inventory differs | 57 | Element counts differ. In 47 cases this group includes extra paragraph elements alongside list items, consistent with tight/loose list rendering differences. It also includes the raw HTML tag-filter example. DOM/CSS and accessibility effects depend on the case. |
| Other attribute inventory differs | 2 | Both tested code-fence cases differ in the generated `class` value. |

These are **primary groups assigned in priority order**, so they add to 189; they are not proven root causes. Other signals overlap. Across all failing cases, the analyzer flags 30 with differing link destinations or link counts, 40 with differing link titles or link counts, 22 with differing image alternative text or image counts, 68 with differing element inventories and 78 with different DOM text including whitespace. Do not add overlapping signal counts together. Case 652 may be subject to browser parser recovery, which can affect element counts.

Five current-suite cases produced an HTML5 parse error in the expected or actual fragment: 144, 512, 515, 603 and 652. Their parsed-tree clusters must be interpreted with particular care. HTML5 parsing is in the default fragment context; a different embedding context, CSS, JavaScript, accessibility tree or security policy can change consequences. HTML5 parse-tree equivalence does not establish Markdown AST equivalence or safety. The whitespace rule never strips whitespace in `pre`, `code`, `script`, `style` or `textarea`, and excludes non-ASCII whitespace, but remains a heuristic.

## Examples of what the differences mean

* **61 — matching HTML5 tree:** expected text contains `&quot;`, actual output uses `"`. Both decode to the same tree in this test, but the original bytes differ.
* **4 — layout whitespace:** expected HTML has a newline between `<li>` and `<p>`; the output does not. This is a strong candidate for a formatting-only difference under common rendering conditions, not an unconditional equivalence guarantee.
* **9 — markup structure:** expected tight list items contain text directly; Swift's formatter emits additional `<p>` elements. This is a real DOM difference even if a particular stylesheet makes it look similar.
* **161 — link title:** expected `<a href="/url" title="title">foo</a>`; Swift emits `<a href="/url">foo</a>`. The tested Swift Markdown AST retains `Link.title`; the inspected `HTMLFormatter.visitLink` does not emit it. This is concrete renderer evidence for this example, not proof about every link failure.
* **525 — image alternative text:** expected `<img src="moon.jpg" alt="moon" />`; Swift emits `<img src="moon.jpg" />`. The tested AST retains `Text("moon")` as an image child, while the inspected image formatter does not emit an `alt` attribute.
* **621 — autolink:** expected `www.commonmark.org` is an anchor; Swift emits plain text. The source example calls for `autolink`, which the tested public parser does not attach. This is a parser-configuration difference with a user-visible effect.
* **652 — tag filtering:** the expected HTML escapes disallowed tags; Swift's output retains them. The reference enables `tagfilter`, which the tested parser does not attach. Raw HTML behavior is separate from a complete host sanitization policy.
* **512 — quoted link destination:** expected `<a href="%22title%22">`, actual contains `<a href=""title"">`. The HTML5 parser reports an attribute parse error in the actual fragment. This merits renderer and host-context review; the cluster does not claim a demonstrated exploit.

Historical suite: 22 same trees, 31 structural-whitespace-only, 55 link-signature differences, 22 image-signature differences, 50 element-inventory differences, and 2 other-attribute differences, totaling 182. Seven cases had an HTML5 parse error on at least one side.

## Reproduce

First regenerate the paired reports as described in [the bundled comparison guide](SWIFT-MARKDOWN-BUNDLED-GFM.md). Install the pinned **development-only** HTML analysis dependencies; these are not SwiftGFM runtime dependencies:

```sh
python3 -m venv .analysis-venv
.analysis-venv/bin/python -m pip install -r Tools/requirements-analysis.txt
.analysis-venv/bin/python Tools/cluster_gfm_failures.py Artifacts/swift-markdown-gfm-current-bundled.json --output Artifacts/swift-markdown-gfm-current-clusters.json
.analysis-venv/bin/python Tools/cluster_gfm_failures.py Artifacts/swift-markdown-gfm-historical-bundled.json --output Artifacts/swift-markdown-gfm-historical-clusters.json
.analysis-venv/bin/python -m unittest discover -s Tools -p 'test_*.py'
```

The JSON outputs contain every failing case's original input, expected and actual strings, per-case unified diff, primary group, overlapping signals, HTML5 parser errors, element counts and link/image signatures. Markdown companions contain a readable diff for every case. Exact strings in JSON are authoritative when a line diff cannot expose a newline or whitespace detail. The reports include fixture and source-report hashes, executable hash, Python and html5lib versions, and reproducibility metadata. Generated artifacts are ignored by git.
