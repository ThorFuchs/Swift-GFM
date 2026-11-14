// SPDX-License-Identifier: Apache-2.0

import SwiftGFM
import Testing

@Test func inputLimitCountsUTF8BytesAndAppliesToParseAndRender() throws {
    let source = "é"
    let allowed = MarkdownEngine(configuration: .init(limits: .init(maximumInputUTF8Bytes: 2)))
    #expect(try allowed.render(source) == "<p>é</p>\n")
    #expect(try allowed.parse(source).source == source)

    let limited = MarkdownEngine(configuration: .init(limits: .init(maximumInputUTF8Bytes: 1)))
    let expected = MarkdownEngineError.resourceLimitExceeded(.inputUTF8Bytes, limit: 1, actual: 2)
    #expect(throws: expected) { try limited.render(source) }
    #expect(throws: expected) { try limited.parse(source) }
    #expect(try limited.render("a") == "<p>a</p>\n")

    let emptyOnly = MarkdownEngine(configuration: .init(limits: .init(maximumInputUTF8Bytes: 0)))
    #expect(try emptyOnly.render("") == "")
    #expect(try emptyOnly.parse("").root.kind == .document)
    #expect(throws: MarkdownEngineError.resourceLimitExceeded(.inputUTF8Bytes, limit: 0, actual: 1)) {
        try emptyOnly.render("\u{0}")
    }
}

@Test func negativeLimitsAreRejectedBeforeUse() throws {
    let examples: [(MarkdownResourceLimit, MarkdownResourceLimits)] = [
        (.inputUTF8Bytes, .init(maximumInputUTF8Bytes: -1)),
        (.astNodes, .init(maximumASTNodes: -1)),
        (.astDepth, .init(maximumASTDepth: -1)),
    ]
    for (kind, limits) in examples {
        let engine = MarkdownEngine(configuration: .init(limits: limits))
        let expected = MarkdownEngineError.invalidResourceLimit(kind, value: -1)
        #expect(throws: expected) { try engine.render("x") }
        #expect(throws: expected) { try engine.parse("x") }
    }
}

@Test func astNodeLimitIncludesRootAndDoesNotAffectRendering() throws {
    let source = "# Title\n"  // document, heading, text
    let allowed = MarkdownEngine(configuration: .init(limits: .init(maximumASTNodes: 3)))
    #expect(try allowed.parse(source).root.children.count == 1)
    #expect(try allowed.parse(source).configuration.limits.maximumASTNodes == 3)

    let limited = MarkdownEngine(configuration: .init(limits: .init(maximumASTNodes: 2)))
    #expect(throws: MarkdownEngineError.resourceLimitExceeded(.astNodes, limit: 2, actual: 3)) {
        try limited.parse(source)
    }
    #expect(try limited.render(source) == "<h1>Title</h1>\n")

    let noNodes = MarkdownEngine(configuration: .init(limits: .init(maximumASTNodes: 0)))
    #expect(throws: MarkdownEngineError.resourceLimitExceeded(.astNodes, limit: 0, actual: 1)) {
        try noNodes.parse("")
    }
    #expect(try noNodes.render("") == "")
}

@Test func astDepthLimitCountsRootAndReportsFirstExceededDepth() throws {
    let source = "> text\n"  // document, block quote, paragraph, text
    let allowed = MarkdownEngine(configuration: .init(limits: .init(maximumASTDepth: 4)))
    #expect(try allowed.parse(source).root.children.count == 1)

    let limited = MarkdownEngine(configuration: .init(limits: .init(maximumASTDepth: 3)))
    #expect(throws: MarkdownEngineError.resourceLimitExceeded(.astDepth, limit: 3, actual: 4)) {
        try limited.parse(source)
    }
    #expect(try limited.render(source) == "<blockquote>\n<p>text</p>\n</blockquote>\n")

    let noDepth = MarkdownEngine(configuration: .init(limits: .init(maximumASTDepth: 0)))
    #expect(throws: MarkdownEngineError.resourceLimitExceeded(.astDepth, limit: 0, actual: 1)) {
        try noDepth.parse("")
    }
}

@Test func astLimitFailureCleansUpAndEngineCanBeReused() throws {
    let engine = MarkdownEngine(configuration: .init(limits: .init(maximumASTDepth: 4)))
    let deep = String(repeating: "> ", count: 2_000) + "text\n"
    for _ in 0..<3 {
        #expect(throws: MarkdownEngineError.resourceLimitExceeded(.astDepth, limit: 4, actual: 5)) {
            try engine.parse(deep)
        }
    }
    #expect(try engine.parse("text\n").root.children.count == 1)
}

@Test func resourceLimitsDefaultToUnlimited() throws {
    let constructor: (MarkdownExtensions, MarkdownOptions, Int) -> MarkdownConfiguration =
        MarkdownConfiguration.init(extensions:options:width:)
    #expect(constructor([], [], 0).limits == .unlimited)
    let engine = MarkdownEngine()
    #expect(engine.configuration.limits == .unlimited)
    let source = String(repeating: "a", count: 100_000)
    #expect(try engine.parse(source).source == source)
    #expect(try engine.render(source).hasPrefix("<p>"))
}

@Test func concurrentEnginesKeepTheirLimitsIndependent() async {
    let limited = MarkdownEngine(configuration: .init(limits: .init(maximumASTNodes: 2)))
    let unlimited = MarkdownEngine()
    let failures = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
        for index in 0..<300 {
            group.addTask {
                do {
                    switch index % 3 {
                    case 0:
                        _ = try limited.parse("x")
                        return true
                    case 1:
                        return try unlimited.parse("x").root.children.count != 1
                    default:
                        return try limited.render("x") != "<p>x</p>\n"
                    }
                } catch let error as MarkdownEngineError {
                    return index % 3 != 0 || error != .resourceLimitExceeded(.astNodes, limit: 2, actual: 3)
                } catch {
                    return true
                }
            }
        }
        var count = 0
        for await failed in group where failed { count += 1 }
        return count
    }
    #expect(failures == 0)
}
