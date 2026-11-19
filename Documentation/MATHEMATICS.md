# Opt-in mathematics parsing

`MarkdownEngine.renderRecognizingMath(_:)` is an additional, HTML-only profile.
It recognizes selected dollar-delimited formulas during cmark parsing, before
Markdown inline interpretation, and returns a sequence of HTML pieces and math
occurrences. It does not render TeX, invoke KaTeX, or change `render(_:)` or
`parse(_:)`. The default SwiftGFM profile remains the pinned cmark backend.

```swift
let document = try MarkdownEngine().renderRecognizingMath("A $x^2$ example.\n")
for part in document.parts {
    switch part {
    case .html(let html):
        // Append this HTML piece to the document stream.
        print(html)
    case .math(let formula):
        // Pass formula.literal and formula.displayMode to a separate renderer.
        print(formula.literal, formula.source, formula.displayMode)
    }
}
```

The pieces together form a document stream; an individual HTML piece need not
be a complete HTML fragment. Formula positions are in HTML text or block
content, not attributes. `index` is zero-based document order. The caller is
responsible for the safety of any inserted renderer output. On a renderer
failure, escape `source` as HTML text before inserting it and report a
diagnostic. No caller callback runs while SwiftGFM holds its parser lock.

## Delimiters and precedence

- Inline math is one line between single `$` characters. The first and last
  content bytes must not be ASCII whitespace; `$$` is not an inline delimiter. A
  backslash-escaped closing dollar remains in the TeX. The first unescaped
  dollar must be a valid closer; a closer followed by an ASCII digit is not
  accepted. These rules avoid some common currency ambiguities; Markdown math
  is not an official part of the pinned GFM grammar and other parsers differ.
- Display math uses either a line containing an opening `$$` and a later line
  containing a closing `$$`, or a single line `$$expression$$`. The delimiter
  lines may have up to three leading spaces in the current Markdown container.
  The closing multiline line contains only the fence and whitespace. Lists and
  block quotes must retain their own continuation prefixes. An unclosed display
  block throws `MarkdownMathError.unclosedDisplay`; callers can fall back to
  the original `render(_:)` output for the whole document.
- Code spans, fenced or indented code blocks, raw HTML tokens, image
  descriptions and GFM table cells do not recognize math. Link text and
  headings can contain inline math; link destinations and titles are not
  parsed as math. Delimiters inside a code block are ordinary code.
- Table cells are deliberately excluded: cmark splits cells and unescapes pipes
  before inline extensions run, so the original TeX cannot be guaranteed there.
  `containsTablesWithoutMath` reports whether the document contains a table;
  it does not claim a table contained a formula. A raw `|` retains GFM's normal
  table-splitting meaning, even between dollar signs.

`literal` preserves the captured UTF-8 spelling, including backslashes and
entities. For multiline display math, it includes the original line endings
and removes Markdown container prefixes. `source` includes the delimiters for
fallback, similarly excluding the surrounding container prefixes and the line
ending after the closing delimiter. SwiftGFM accepts Swift strings, and rejects
NUL in this profile because cmark replaces it before extension callbacks.

Raw HTML must be disabled: `allowUnsafeHTML` is rejected so that a formula
cannot be emitted into an author-controlled HTML attribute, comment, script,
or other raw context. This restriction does not make the remaining HTML a
complete sanitizer. A bounded scan prevents unbounded repeated delimiter
search; exceeding the bound throws `MarkdownMathError.parserUnavailable`.
The usual engine input limits apply. AST projection limits do not constrain
rendering, and there is no hard memory or execution-time limit on cmark.
