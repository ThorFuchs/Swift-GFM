# Rendering formats and options

Use one string-to-string API to invoke any of cmark-gfm's six renderers.

## Choose a format

``MarkdownEngine/render(_:as:)`` accepts ``MarkdownOutputFormat/html``,
``MarkdownOutputFormat/xml``, ``MarkdownOutputFormat/commonMark``,
``MarkdownOutputFormat/plainText``, ``MarkdownOutputFormat/latex``, and
``MarkdownOutputFormat/man``. XML is cmark's AST serialization, not XHTML.
Its precise representation is tied to the pinned backend revision; it is not a
lossless copy of the source. The CommonMark output is a normalized Markdown
serialization and is not a source-preserving editor format.

```swift
let engine = MarkdownEngine()
let xml = try engine.render("**important**", as: .xml)
let latex = try engine.render("**important**", as: .latex)
```

The native XML can contain characters that an XML 1.0 parser rejects, and a
standard XML parser may normalize whitespace in attributes. The read-only
``MarkdownDocument`` API traverses the C tree directly and avoids that XML
round trip.

## Configure behavior

``MarkdownConfiguration`` holds ``MarkdownExtensions``, ``MarkdownOptions``,
and a wrap width. A width of zero disables wrapping; negative values and values
larger than `Int32.max` cause ``MarkdownEngineError/invalidWidth(_:)``. Unknown
extension bits cause an error. Unknown option bits are passed to the C backend.

``MarkdownOptions/sourcePositions`` requests source positions, while
``MarkdownOptions/smartPunctuation`` enables typography transformations.
``MarkdownOptions/allowUnsafeHTML`` changes cmark's HTML handling. See
<doc:ConcurrencyAndSecurity> before rendering untrusted input.

## Handle errors

``MarkdownEngine/render(_:as:)`` and ``MarkdownEngine/parse(_:)`` throw
``MarkdownEngineError``. Compare its ``MarkdownEngineError/code`` with the
``MarkdownEngineError/Code`` values and read the optional context properties,
such as ``MarkdownEngineError/resourceLimit`` or ``MarkdownEngineError/detail``:

```swift
do {
    _ = try engine.render(input)
} catch let error as MarkdownEngineError {
    switch error.code {
    case .resourceLimitExceeded: print("input too large:", error.value ?? 0)
    case .invalidWidth: print("invalid width:", error.value ?? 0)
    default: print(error)
    }
}
```

Future minor versions can add codes, so keep a `default` case.
