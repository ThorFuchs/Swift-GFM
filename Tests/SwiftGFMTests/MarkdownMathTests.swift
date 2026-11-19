// SPDX-License-Identifier: Apache-2.0
import Testing

@testable import SwiftGFM

@Test func mathCapturesOriginalInlineAndDisplay() throws {
    let input = "Before $a*b + \\alpha\\_x$ after.\n\n$$\r\nx \\| y\r\n$$\r\n"
    let document = try MarkdownEngine().renderRecognizingMath(input)
    let occurrences = document.parts.compactMap { part -> MarkdownMathOccurrence? in
        if case .math(let value) = part { return value }
        return nil
    }
    #expect(occurrences.count == 2)
    #expect(occurrences[0].literal == "a*b + \\alpha\\_x")
    #expect(occurrences[0].source == "$a*b + \\alpha\\_x$")
    #expect(occurrences[0].displayMode == false)
    #expect(occurrences[1].literal == "x \\| y\r\n")
    #expect(occurrences[1].source == "$$\r\nx \\| y\r\n$$")
    #expect(occurrences[1].displayMode == true)
}

@Test func mathExcludesCodeEscapedDollarsAndImageAlt() throws {
    let input = "`$code$` \\$literal\\$ ![$alt$](img.png) and $yes$\n"
    let doc = try MarkdownEngine().renderRecognizingMath(input)
    let occurrences = doc.parts.compactMap { part -> MarkdownMathOccurrence? in
        if case .math(let value) = part { return value }
        return nil
    }
    #expect(occurrences.map(\.literal) == ["yes"])
}

@Test func mathRefusesUnsafeRawHTMLAndUnclosedDisplay() throws {
    let unsafe = MarkdownEngine(configuration: .init(options: [.allowUnsafeHTML]))
    #expect(throws: MarkdownMathError.unsafeHTML) { try unsafe.renderRecognizingMath("$x$") }
    #expect(throws: MarkdownMathError.unclosedDisplay) { try MarkdownEngine().renderRecognizingMath("$$\nx\n") }
}

@Test func mathHandlesContainersAndTablesConservatively() throws {
    let input = "> $$\n> x * y\n> $$\n\n- $$z^2$$\n\n| H |\n| --- |\n| $a\\|b$ |\n"
    let result = try MarkdownEngine().renderRecognizingMath(input)
    let occurrences = result.parts.compactMap { part -> MarkdownMathOccurrence? in
        if case .math(let value) = part { return value }
        return nil
    }
    #expect(occurrences.map(\.literal) == ["x * y\n", "z^2"])
    #expect(occurrences.map(\.displayMode) == [true, true])
    #expect(result.containsTablesWithoutMath)
}

@Test func mathHandlesLinksEntitiesAndCurrency() throws {
    let input = "[$a&amp;b$](https://example.com) costs $12 and $34, then $x$.\n"
    let result = try MarkdownEngine().renderRecognizingMath(input)
    let occurrences = result.parts.compactMap { part -> MarkdownMathOccurrence? in
        if case .math(let value) = part { return value }
        return nil
    }
    #expect(occurrences.map(\.literal) == ["a&amp;b", "x"])
}

@Test func mathPreservesDocumentStreamAndExcludesUnsafeContexts() throws {
    let input = """
        # Hello $x_1$

        [link $a+b$](https://example.com)

        `code $no$` ![image $no$](image.png)

        <!-- $no$ -->

        ```
        $no$
        ```

        $$
        x + y
        $$
        """
    let result = try MarkdownEngine().renderRecognizingMath(input)
    var ids: [Int] = []
    var stream = ""
    for part in result.parts {
        switch part {
        case .html(let html): stream += html
        case .math(let math):
            ids.append(math.index)
            stream += math.displayMode ? "<div>DISPLAY</div>" : "<span>INLINE</span>"
        }
    }
    #expect(ids == [0, 1, 2])
    #expect(stream.contains("<h1>Hello <span>INLINE</span></h1>"))
    #expect(stream.contains("<a href=\"https://example.com\">link <span>INLINE</span></a>"))
    #expect(stream.contains("alt=\"image $no$\""))
    #expect(stream.contains("<code>code $no$</code>"))
    #expect(stream.contains("<pre><code>$no$"))
    #expect(stream.contains("<div>DISPLAY</div>"))
    #expect(!stream.contains("SWIFTGFMMATH"))
}

@Test func mathLeavesOrdinaryDocumentBytesUnchanged() throws {
    let examples = [
        "plain text\n", "# Heading\n\n- one\n- two\n", "A \\$literal\\$ and `$code$`.\n", "| H |\n| - |\n| $x$ |\n",
    ]
    for input in examples {
        let engine = MarkdownEngine()
        let parts = try engine.renderRecognizingMath(input).parts
        let html = parts.compactMap { part -> String? in
            if case .html(let value) = part { return value }
            return nil
        }.joined()
        #expect(
            parts.allSatisfy {
                if case .html = $0 { return true }
                return false
            })
        #expect(html == (try engine.render(input)))
    }
}

@Test func mathEscapeParityAndMalformedInputs() throws {
    let source = #"\$escaped\$ \\$x$ $a\$b$ $3.50 and $7.00; $ok$."#
    let result = try MarkdownEngine().renderRecognizingMath(source)
    let formulas = result.parts.compactMap { part -> MarkdownMathOccurrence? in
        if case .math(let value) = part { return value }
        return nil
    }
    #expect(formulas.map(\.literal) == ["x", #"a\$b"#, "ok"])
    #expect(formulas.map(\.source) == ["$x$", #"$a\$b$"#, "$ok$"])
    #expect(throws: MarkdownMathError.nulInSource) { try MarkdownEngine().renderRecognizingMath("$x\0$") }
}

@Test func mathParsingIsSerializedWithRegularRendering() async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        for index in 0..<50 {
            group.addTask {
                let engine = MarkdownEngine()
                let document = try engine.renderRecognizingMath("$x_\(index)$")
                let found = document.parts.compactMap { part -> String? in
                    if case .math(let value) = part { return value.literal }
                    return nil
                }
                #expect(found == ["x_\(index)"])
                #expect(try engine.render("**plain**") == "<p><strong>plain</strong></p>\n")
            }
        }
        try await group.waitForAll()
    }
}

@Test func mathSupportsUnicodeAndBothDisplayStylesAtEndOfFile() throws {
    let cases = [
        ("Größe $α+β$", "α+β", "$α+β$", false),
        ("$$\\frac{1}{2}$$", "\\frac{1}{2}", "$$\\frac{1}{2}$$", true),
        ("$$\rα+β\r$$", "α+β\r", "$$\rα+β\r$$", true),
    ]
    for (input, literal, source, display) in cases {
        let parts = try MarkdownEngine().renderRecognizingMath(input).parts
        let formulas = parts.compactMap { part -> MarkdownMathOccurrence? in
            if case .math(let value) = part { return value }
            return nil
        }
        #expect(formulas.count == 1)
        #expect(formulas.first?.literal == literal)
        #expect(formulas.first?.source == source)
        #expect(formulas.first?.displayMode == display)
    }
}

@Test func mathRecognitionStopsAtUnsafeDollarRuns() throws {
    for input in ["$ a$", "$a $", "$a$$", "$$a$", "unmatched $x", "\\$$x\\$$"] {
        let parts = try MarkdownEngine().renderRecognizingMath(input).parts
        #expect(
            parts.allSatisfy {
                if case .html = $0 { return true }
                return false
            }, "\(input)")
    }
}

@Test func mathManyFormulasKeepDocumentOrder() throws {
    let source = (0..<2500).map { "$x_\($0)$" }.joined(separator: " ")
    let document = try MarkdownEngine().renderRecognizingMath(source)
    let occurrences = document.parts.compactMap { part -> MarkdownMathOccurrence? in
        if case .math(let value) = part { return value }
        return nil
    }
    #expect(occurrences.count == 2500)
    #expect(
        occurrences.enumerated().allSatisfy { index, occurrence in
            occurrence.index == index && occurrence.literal == "x_\(index)"
        })
}

@Test func mathDoesNotExposeHTMLAttributesOrComments() throws {
    let input =
        #"Text <span title="$attr$">$content$</span> <!-- $comment$ --> [link](https://example.com "$title$") ![$alt$](image.png)"#
    let result = try MarkdownEngine().renderRecognizingMath(input)
    let formulas = result.parts.compactMap { part -> String? in
        if case .math(let value) = part { return value.literal }
        return nil
    }
    #expect(formulas == ["content"])
}

@Test func mathKeepsCombiningCharactersAdjacentToMarkers() throws {
    for scalar in ["\u{301}", "\u{200D}", "\u{FE0F}"] {
        let result = try MarkdownEngine().renderRecognizingMath("a\(scalar)$x$\(scalar)\n")
        guard case .html(let prefix) = result.parts.first, case .html(let suffix) = result.parts.last else {
            Issue.record("Missing surrounding HTML")
            return
        }
        #expect(Array(prefix.utf8) == Array("<p>a\(scalar)".utf8))
        #expect(Array(suffix.utf8) == Array("\(scalar)</p>\n".utf8))
    }
}

@Test func mathDoesNotConsumeCodeAfterCurrencyAndEscapes() throws {
    let source = "a $x$\u{301}, ❤️$y$; Preis $5 und $10; \\$z\\$; `$q$`."
    let document = try MarkdownEngine().renderRecognizingMath(source)
    var formulas: [String] = []
    var html = ""
    for part in document.parts {
        switch part {
        case .html(let value): html += value
        case .math(let value):
            formulas.append(value.literal)
            html += "<math></math>"
        }
    }
    #expect(formulas == ["x", "y"])
    #expect(html.contains("Preis $5 und $10; $z$; <code>$q$</code>"))
}
