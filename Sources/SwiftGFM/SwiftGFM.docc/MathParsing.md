# Optional math-aware HTML

Recognize selected dollar-delimited formulas before Markdown inline parsing.

``MarkdownEngine/renderRecognizingMath(_:)`` returns ``MarkdownMathDocument``
with ordered ``MarkdownMathPart`` values. HTML pieces form a document stream;
the caller renders each ``MarkdownMathOccurrence`` separately after this call
returns. SwiftGFM does not invoke KaTeX or trust its output.

```swift
let document = try MarkdownEngine().renderRecognizingMath("A $x^2$ example.\n")
for part in document.parts {
    switch part {
    case .html(let html): print(html)
    case .math(let formula): print(formula.literal, formula.displayMode)
    }
}
```

Inline math requires single dollars on one line; its content cannot start or
end with ASCII whitespace. Display math uses separate `$$` lines, or a standalone `$$x$$` line.
Escaped delimiters, invalid or missing closers, and currency-like input follow
the rules in the repository's mathematics guide. An unclosed display block
throws ``MarkdownMathError/unclosedDisplay``; callers can render the original
document with ``MarkdownEngine/render(_:as:)`` instead.

Code, raw HTML tokens, image descriptions, and table cells do not recognize
math. ``MarkdownMathDocument/containsTablesWithoutMath`` reports the presence
of tables, not the presence of a formula. Table cells are excluded because the
backend splits cells and unescapes pipes before inline extensions run.

``MarkdownMathOccurrence/literal`` retains TeX spelling, including backslashes
and entities. For multiline display blocks it retains original line endings
but omits Markdown container prefixes. ``MarkdownMathOccurrence/source``
includes delimiters for a readable, HTML-escaped fallback. Raw HTML passthrough
and NUL input are rejected by this profile. Neither the result nor inserted
renderer output is automatically sanitized. See <doc:ConcurrencyAndSecurity>.
