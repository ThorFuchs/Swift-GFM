# GitHub Flavored Markdown syntax

Learn the syntax supported by the pinned backend and try complete examples.

## What this guide describes

SwiftGFM uses GitHub's cmark-gfm `0.29.0.gfm.13` at revision
`27d942c8b0a62d192f616e5bf3578f4b6a89e180`. This guide introduces common
constructs using the library's default configuration. For the complete grammar,
precedence rules, and edge cases, consult the
[GFM specification](https://github.github.com/gfm/) (version 0.29-gfm).
The specification and this backend are distinct: SwiftGFM promises fidelity to
the pinned backend, not full specification conformance. GitHub.com also applies
additional processing and sanitization after Markdown rendering.

``MarkdownEngine`` and ``MarkdownConfiguration/gfm`` enable tables,
strikethrough, extended autolinks, tag filtering, and task lists. Footnotes
and smart punctuation are separate options and are **off** by default.
The `swift-gfm` command starts with **no extensions**; pass the desired `-e`
flags explicitly. The [example gallery](https://github.com/ThorFuchs/Swift-GFM/tree/main/Examples)
contains runnable Markdown and its actual HTML output.

## Paragraphs and headings

Separate paragraphs with a blank line. One to six `#` markers followed by a
space introduce headings; an underline of `=` or `-` also forms a heading.
A soft line break within a paragraph normally remains a newline in the HTML;
two trailing spaces or a backslash before a newline request a hard break.

```markdown
# Field notes

First paragraph.

## A smaller heading

Another paragraph with a\
hard line break.
```

Three or more matching `*`, `-`, or `_` markers on a line form a thematic
break; spaces between the markers are allowed. A line of dashes can instead
be interpreted as a setext heading underline when it follows paragraph text,
so use a blank line when you intend a separate break.

## Emphasis, code spans, and escapes

Use `*` or `_` for emphasis, double markers for strong emphasis, and `~~`
for strikethrough when that extension is enabled. Backticks delimit inline code.
Use a longer run of backticks around code containing a backtick. A backslash
before ASCII punctuation can make the punctuation literal; character
references such as `&amp;` are decoded outside code.

```markdown
*emphasis* and **strong** and ~~removed~~

`render(markdown)` and \*literal asterisks\*
```

Delimiter context matters; for the complete rules, see
[emphasis and strong emphasis](https://github.github.com/gfm/#emphasis-and-strong-emphasis).
The backend accepts single-tilde strikethrough by default as well; use
``MarkdownOptions/doubleTildeStrikethrough`` to require two tildes.

## Lists and task lists

Start an unordered item with `-`, `+`, or `*`, followed by a space. Ordered
items use a number followed by `.` or `)`. Indent nested content under the
item's text. Blank lines affect whether a list is rendered as tight or loose.

```markdown
1. Prepare
2. Publish
   - [x] Write notes
   - [ ] Ask for feedback
```

The task-list extension recognizes `[ ]`, `[x]`, or `[X]` at the start of a
list item and generates disabled HTML checkboxes. The rendered checkbox is a
display of Markdown state, not an interactive editor.

## Tables

With the table extension, a header and delimiter row introduce a table. The
header and delimiter must have the same number of cells. A colon on the left,
right, or both sides of a delimiter controls alignment. Escape a literal pipe
as `\|`. Cell contents are parsed as inline Markdown, not blocks.

```markdown
| Feature | Status | Count |
| :--- | :---: | ---: |
| Tables | **Ready** | 3 |
| Tasks | Ready | 4 |
```

See the [table rules](https://github.github.com/gfm/#tables-extension) for
missing or extra cells and other edge cases.

## Links, images, and autolinks

Use a label and destination for a link, and add an exclamation mark for
an image. Reference definitions can share a destination. Angle brackets form
ordinary URI or email autolinks. With the autolink extension enabled, supported
bare URLs and email addresses can also become links.

```markdown
[Swift](https://swift.org) and [the guide][guide]

![A compass](compass.png)

Visit https://example.com or write hello@example.com.

[guide]: https://example.org/guide "Guide"
```

The backend filters certain unsafe link destinations by default. Link and image
loading, URL handling, and HTML sanitization remain the host application's
responsibility; see <doc:ConcurrencyAndSecurity>.

## Code blocks and block quotes

Use fences of at least three backticks or tildes for a code block. An optional
info string can identify a language. SwiftGFM emits a language class in HTML;
syntax highlighting requires a separate presentation layer. Four-space
indentation can also introduce a code block in the appropriate context.

````markdown
```swift
let html = try MarkdownEngine().render("Hello, *world*!")
```

> A block quote may contain **formatted text**.
>
> - And a list
````

## HTML and tag filtering

Raw HTML is recognized by the parser, but the default HTML renderer omits raw
HTML and filters some unsafe URLs. ``MarkdownOptions/allowUnsafeHTML`` allows
raw HTML through and changes URL handling. With the tag-filter extension,
certain potentially dangerous tags are filtered even in unsafe mode. Neither
mode provides a complete HTML sanitizer. Review <doc:ConcurrencyAndSecurity>
before rendering untrusted input.

## Optional footnotes and typography

Footnotes are a backend option outside the default GFM extension set. Enable
them explicitly before using a reference and its definition:

```swift
let engine = MarkdownEngine(configuration: .init(options: [.footnotes]))
let html = try engine.render("A note.[^a]\n\n[^a]: More detail.\n")
```

The corresponding CLI flag is `-e footnotes`. Smart punctuation is another
opt-in option (``MarkdownOptions/smartPunctuation``, or `--smart` in the CLI).
These options should not be assumed from the default GFM configuration.

## Try the examples

The [gallery](https://github.com/ThorFuchs/Swift-GFM/tree/main/Examples) pairs
eight source files with HTML produced by SwiftGFM and styled browser previews.
For example, from the repository root:

```sh
swift run swift-gfm html -e table -e strikethrough -e autolink -e tagfilter -e tasklist Examples/Markdown/04-tables.md > /tmp/swift-gfm-table.html
```

The CSS in the screenshots is presentation only: SwiftGFM returns an HTML
fragment and does not provide a stylesheet or syntax highlighting.
