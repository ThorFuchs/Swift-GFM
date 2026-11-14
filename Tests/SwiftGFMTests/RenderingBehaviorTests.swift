// SPDX-License-Identifier: Apache-2.0

import SwiftGFM
import Testing

// Expected bytes below were obtained from the independently built pinned
// github/cmark-gfm executable, with --unsafe and no syntax extensions.
private struct FormatExample: Sendable {
    let format: MarkdownOutputFormat
    let expected: String
}

private let formatExamples: [FormatExample] = [
    .init(format: .html, expected: "<h1>Title</h1>\n<p>A <em>test</em>.</p>\n"),
    .init(
        format: .xml,
        expected: """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE document SYSTEM "CommonMark.dtd">
            <document xmlns="http://commonmark.org/xml/1.0">
              <heading level="1">
                <text xml:space="preserve">Title</text>
              </heading>
              <paragraph>
                <text xml:space="preserve">A </text>
                <emph>
                  <text xml:space="preserve">test</text>
                </emph>
                <text xml:space="preserve">.</text>
              </paragraph>
            </document>

            """),
    .init(format: .commonMark, expected: "# Title\n\nA *test*.\n"),
    .init(format: .plainText, expected: "Title\n\nA test.\n"),
    .init(format: .latex, expected: "\\section{Title}\n\nA \\emph{test}.\n"),
    .init(format: .man, expected: ".SH\nTitle\n.PP\nA \\f[I]test\\f[].\n"),
]

@Test("Six renderer outputs match pinned cmark bytes", arguments: formatExamples)
private func exactReferenceFormats(_ example: FormatExample) throws {
    let engine = MarkdownEngine(configuration: .init(extensions: [], options: [.allowUnsafeHTML]))
    let actual = try engine.render("# Title\n\nA *test*.\n", as: example.format)
    #expect(Array(actual.utf8) == Array(example.expected.utf8))
}

@Test func cmarkLineBreakAndTypographyOptions() throws {
    let source = "one\ntwo\n"
    #expect(try MarkdownEngine(configuration: .cmarkDefault).render(source) == "<p>one\ntwo</p>\n")
    #expect(
        try MarkdownEngine(configuration: .init(extensions: [], options: [.hardBreaks])).render(source)
            == "<p>one<br />\ntwo</p>\n")
    #expect(
        try MarkdownEngine(configuration: .init(extensions: [], options: [.noBreaks])).render(source)
            == "<p>one two</p>\n")
    #expect(
        try MarkdownEngine(configuration: .init(extensions: [], options: [.smartPunctuation])).render(
            "\"Hello\" -- ...\n")
            == "<p>“Hello” – …</p>\n")
}

@Test func cmarkHTMLPoliciesAreExplicit() throws {
    let source = "<script>alert(1)</script>\n\n[x](javascript:alert(1))\n"
    #expect(
        try MarkdownEngine(configuration: .cmarkDefault).render(source)
            == "<!-- raw HTML omitted -->\n<p><a href=\"\">x</a></p>\n")
    #expect(
        try MarkdownEngine(configuration: .init(extensions: [], options: [.allowUnsafeHTML])).render(source)
            == "<script>alert(1)</script>\n<p><a href=\"javascript:alert(1)\">x</a></p>\n")
    let filtered = MarkdownEngine(configuration: .init(extensions: [.tagFilter], options: [.allowUnsafeHTML]))
    #expect(try filtered.render("<script>alert(1)</script>\n") == "&lt;script>alert(1)&lt;/script>\n")
}

@Test func cmarkCodeInfoOption() throws {
    let engine = MarkdownEngine(configuration: .init(extensions: [], options: [.fullInfoString]))
    let html = try engine.render("```swift other words\nx\n```\n")
    #expect(html == "<pre><code class=\"language-swift\" data-meta=\"other words\">x\n</code></pre>\n")
}

@Test func configurationBoundsAndStringBytes() throws {
    for width in [-1, Int(Int32.max) + 1] {
        let engine = MarkdownEngine(configuration: .init(extensions: [], width: width))
        #expect(throws: MarkdownEngineError.invalidWidth(width)) { try engine.render("x") }
        #expect(throws: MarkdownEngineError.invalidWidth(width)) { try engine.parse("x") }
    }
    let decomposed = "e\u{301}"
    let expected = "<p>e\u{301}</p>\n"
    let actual = try MarkdownEngine().render(decomposed)
    // Swift String equality is canonically equivalent; compare exact UTF-8 bytes.
    #expect(Array(actual.utf8) == Array(expected.utf8))
    #expect(Array(actual.utf8) != Array("<p>é</p>\n".utf8))
    #expect(try MarkdownEngine().render("") == "")
    #expect(try MarkdownEngine().parse("").root.kind == .document)
}

@Test func unsupportedOptionBitsAreRejected() throws {
    #expect(MarkdownOptions.supported.contains(.allowUnsafeHTML))
    #expect(MarkdownOptions.supported.rawValue & (1 << 0 | 1 << 3 | 1 << 8) == 0)
    for bits: UInt32 in [1 << 0, 1 << 3, 1 << 8, 1 << 18, 1 << 31] {
        let engine = MarkdownEngine(configuration: .init(options: MarkdownOptions(rawValue: bits)))
        #expect(throws: MarkdownEngineError.unsupportedOptions(bits)) { try engine.render("x") }
        #expect(throws: MarkdownEngineError.unsupportedOptions(bits)) { try engine.parse("x") }
    }
    let mixed = MarkdownEngine(configuration: .init(options: [.smartPunctuation, MarkdownOptions(rawValue: 1 << 20)]))
    #expect(throws: MarkdownEngineError.unsupportedOptions(1 << 20)) { try mixed.render("x") }
    let all = MarkdownEngine(configuration: .init(options: .supported))
    #expect(try all.render("x\n").contains("x"))
}

@Test func emptyAndLargeInputsAreFedWithoutCopies() throws {
    #expect(try MarkdownEngine().render("") == "")
    #expect(try MarkdownEngine().parse("").root.children.isEmpty)
    let large = String(repeating: "word ", count: 200_000) + "\n"
    #expect(try MarkdownEngine().render(large).hasPrefix("<p>word word"))
}
