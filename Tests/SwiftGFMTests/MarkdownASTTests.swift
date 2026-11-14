// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing

@testable import SwiftGFM

private func kinds(_ document: MarkdownDocument) -> [MarkdownNodeKind] {
    var values: [MarkdownNodeKind] = []
    document.walk { node in
        values.append(node.kind)
        return .visitChildren
    }
    return values
}

@Test func astCapturesCommonMarkProperties() throws {
    let source = "# Hi *friend*\n\n3) [a](https://example.com \"title\")\n4) ![alt](/i)\n\n```swift\nlet x = 1\n```\n"
    let configuration = MarkdownConfiguration(options: [.sourcePositions])
    let document = try MarkdownEngine(configuration: configuration).parse(source)
    #expect(document.source == source)
    #expect(document.configuration == configuration)
    #expect(document.root.kind == .document)
    let nodes = kinds(document)
    #expect(nodes.contains(.heading(level: 1)))
    #expect(nodes.contains(.emphasis))
    #expect(nodes.contains(.list(style: .ordered(start: 3, delimiter: .parenthesis), tight: true)))
    #expect(nodes.contains(.link(destination: "https://example.com", title: "title")))
    #expect(nodes.contains(.image(destination: "/i", title: "")))
    #expect(
        nodes.contains(
            .codeBlock(
                literal: "let x = 1\n", info: "swift", fence: MarkdownCodeFence(character: "`", length: 3, offset: 0))))
    #expect(
        document.root.children[0].range
            == MarkdownSourceRange(
                start: MarkdownSourcePosition(line: 1, column: 1), end: MarkdownSourcePosition(line: 1, column: 13)))
    #expect(try MarkdownEngine(configuration: .cmarkDefault).parse(source).root.range == nil)
}

@Test func astCapturesGFMExtensionsAndOptions() throws {
    let source = "| left | right |\n| :-- | --: |\n| ~~x~~ | y |\n\n- [x] done\n- [ ] todo\n\nwww.example.com\n"
    let values = kinds(try MarkdownEngine().parse(source))
    #expect(values.contains(.table(alignments: [.left, .right])))
    #expect(values.contains(.tableRow(isHeader: true)))
    #expect(values.contains(.tableRow(isHeader: false)))
    #expect(values.contains(.strikethrough))
    #expect(values.contains { if case .taskListItem(_, true) = $0 { true } else { false } })
    #expect(values.contains { if case .taskListItem(_, false) = $0 { true } else { false } })
    #expect(values.contains(.link(destination: "http://www.example.com", title: "")))
    let plainValues = kinds(try MarkdownEngine(configuration: .cmarkDefault).parse(source))
    #expect(!plainValues.contains { if case .table = $0 { true } else { false } })
    #expect(!plainValues.contains(.strikethrough))
}

@Test func astPreservesValuesThatXMLParsersCannot() throws {
    let source = "hi\u{01}there\n\n[foo]: /url \"\ntitle\n\"\n\n[foo]\n"
    let values = kinds(try MarkdownEngine().parse(source))
    #expect(values.contains(.text("hi\u{01}there")))
    #expect(values.contains(.link(destination: "/url", title: "\ntitle\n")))
}

@Test func astFootnotesHaveConcreteKinds() throws {
    let engine = MarkdownEngine(configuration: .init(options: [.footnotes]))
    let values = kinds(try engine.parse("A[^label].\n\n[^label]: Footnote.\n"))
    #expect(values.contains(.footnoteReference(literal: "1")))
    #expect(values.contains(.footnoteDefinition(literal: "label")))
}

@Test func footnoteASTRemainsUsableWhenBackendXMLIsNotWellFormed() throws {
    let engine = MarkdownEngine(configuration: .init(options: [.footnotes]))
    let source = "A[^n].\n\n[^n]: note\n"
    let xml = try engine.render(source, as: .xml)
    // These exact node names come from the pinned backend; the wrapper does not
    // silently rewrite its XML. The Swift AST is copied directly from C nodes.
    #expect(xml.contains("<<unknown> />"))
    #expect(xml.contains("</<unknown>>"))
    let values = kinds(try engine.parse(source))
    #expect(values.contains(.footnoteReference(literal: "1")))
    #expect(values.contains(.footnoteDefinition(literal: "n")))
}

@Test func astHandlesLongUnicodeNULAndNestedBlocks() throws {
    let source = String(repeating: "λ", count: 50_000) + "\u{0}end\n"
    let values = kinds(try MarkdownEngine().parse(source))
    #expect(values.contains(.text(String(repeating: "λ", count: 50_000) + "\u{FFFD}end")))
    let nested = try MarkdownEngine().parse(String(repeating: "> ", count: 256) + "text\n")
    #expect(kinds(nested).filter { $0 == .blockQuote }.count == 256)
    #expect(throws: MarkdownEngineError.unsupportedExtensions(128)) {
        try MarkdownEngine(configuration: .init(extensions: .init(rawValue: 128))).parse("x")
    }
}

@Test func astReleasesDeeplyNestedDocument() throws {
    // The upstream pathological corpus covers rendering; this additionally
    // exercises retaining, walking, and releasing the independently owned AST.
    func parseAndRelease() throws {
        let depth = 50_000
        let document = try MarkdownEngine().parse(String(repeating: "> ", count: depth) + "text\n")
        var blocks = 0
        document.walk { node in
            if case .blockQuote = node.kind { blocks += 1 }
            return .visitChildren
        }
        #expect(blocks == depth)
    }
    try parseAndRelease()
}

@Test func astSubtreeSurvivesOriginalDocument() throws {
    func parsedHeading() throws -> MarkdownNode {
        let document = try MarkdownEngine().parse("# Hello *Swift*\n\nAnother paragraph\n")
        return document.root.children[0]
    }
    let heading = try parsedHeading()
    #expect(heading.kind == .heading(level: 1))
    var text: [String] = []
    heading.walk { node in
        if case .text(let value) = node.kind { text.append(value) }
        return .visitChildren
    }
    #expect(text == ["Hello ", "Swift"])
}

private struct SkippingVisitor: MarkdownVisitor {
    var kinds: [MarkdownNodeKind] = []
    mutating func visit(_ node: MarkdownNode) -> MarkdownWalkControl {
        kinds.append(node.kind)
        return node.kind == .emphasis ? .skipChildren : .visitChildren
    }
}

@Test func astWalkerSupportsPreorderPruningStoppingAndErrors() throws {
    let doc = try MarkdownEngine().parse("A *hidden* B\n\nNext\n")
    var visitor = SkippingVisitor()
    doc.walk(&visitor)
    #expect(visitor.kinds.contains(.emphasis))
    #expect(!visitor.kinds.contains(.text("hidden")))
    var count = 0
    doc.walk { _ in
        count += 1
        return .stop
    }
    #expect(count == 1)
    count = 0
    doc.root.children[0].walk { _ in
        count += 1
        return .visitChildren
    }
    #expect(count < kinds(doc).count)
    enum Marker: Error { case encountered }
    #expect(throws: Marker.encountered) {
        try doc.walk { _ in throw Marker.encountered }
    }
}

@Test func concurrentASTAndRenderCalls() async throws {
    let engine = MarkdownEngine()
    let source = "# Hello *world*\n\n- [x] task\n"
    let expected = kinds(try engine.parse(source))
    let expectedHTML = try engine.render(source)
    let failures = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
        for index in 0..<400 {
            group.addTask {
                do {
                    if index.isMultiple(of: 2) { return kinds(try engine.parse(source)) != expected }
                    return try engine.render(source) != expectedHTML
                } catch { return true }
            }
        }
        var count = 0
        for await failed in group where failed { count += 1 }
        return count
    }
    #expect(failures == 0)
    let snapshot = try engine.parse(source)
    let detachedCount = await Task.detached { kinds(snapshot).count }.value
    #expect(detachedCount == expected.count)
    let walkFailures = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
        for _ in 0..<200 { group.addTask { kinds(snapshot) != expected } }
        var count = 0
        for await failed in group where failed { count += 1 }
        return count
    }
    #expect(walkFailures == 0)
}
