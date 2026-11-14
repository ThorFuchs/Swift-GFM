// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing

@testable import SwiftGFM

@Test func rendersAllFormatsAndInspectsAST() throws {
    var config = MarkdownConfiguration(extensions: [.strikethrough], options: [.allowUnsafeHTML, .sourcePositions])
    let engine = MarkdownEngine(configuration: config)
    let source = "# Hi\n\n~~old~~\n"
    let html = try engine.render(source, as: .html)
    #expect(html.contains("<del>old</del>"))
    let xml = try engine.render(source, as: .xml)
    #expect(xml.contains("<document sourcepos="))
    #expect(xml.contains("<strikethrough"))
    #expect(xml.contains("<text"))
    #expect(try engine.render(source, as: .commonMark).contains("~~old~~"))
    #expect(try engine.render(source, as: .plainText).contains("old"))
    #expect(try engine.render(source, as: .latex).contains("\\sout{old}"))
    #expect(try engine.render(source, as: .man).contains(".SH"))
    #expect(MarkdownEngine.backendVersion == "0.29.0.gfm.13")
    config.width = -1
    #expect(throws: MarkdownEngineError.invalidWidth(-1)) { try MarkdownEngine(configuration: config).render(source) }
}

@Test func presetAndSafetyAreExplicit() throws {
    let input = "www.example.com\n\n<script>x</script>\n"
    let safe = try MarkdownEngine().render(input)
    #expect(safe.contains("<a href=\"http://www.example.com\">"))
    #expect(!safe.contains("<script>"))
    let plain = try MarkdownEngine(configuration: .cmarkDefault).render("www.example.com\n")
    #expect(plain == "<p>www.example.com</p>\n")
    let unsafe = try MarkdownEngine(configuration: .init(options: [.allowUnsafeHTML])).render("<script>x</script>\n")
    #expect(unsafe == "<script>x</script>\n")
    #expect(throws: MarkdownEngineError.unsupportedExtensions(128)) {
        try MarkdownEngine(configuration: .init(extensions: .init(rawValue: 128))).render("x")
    }
}

private struct RenderCase: Sendable {
    let engine: MarkdownEngine
    let source: String
    let format: MarkdownOutputFormat
    let expected: String
}

@Test func concurrentMixedCallsAreDeterministic() async throws {
    let engines = [
        MarkdownEngine(configuration: .cmarkDefault), MarkdownEngine(configuration: .gfm),
        MarkdownEngine(
            configuration: .init(
                extensions: [.table, .strikethrough], options: [.allowUnsafeHTML, .sourcePositions], width: 40)),
    ]
    let sources = ["*x* ~~y~~\n", "| A | B |\n| - | - |\n| a | b |\n", "www.example.com\n\n<script>x</script>\n"]
    var cases: [RenderCase] = []
    for engine in engines {
        for source in sources {
            for format in MarkdownOutputFormat.allCases {
                cases.append(
                    RenderCase(
                        engine: engine, source: source, format: format, expected: try engine.render(source, as: format))
                )
            }
        }
    }
    let inputs = cases
    let mismatches = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
        for index in 0..<1_200 {
            let test = inputs[index % inputs.count]
            group.addTask {
                do { return try test.engine.render(test.source, as: test.format) != test.expected } catch {
                    return true
                }
            }
        }
        var count = 0
        for await mismatch in group { if mismatch { count += 1 } }
        return count
    }
    #expect(mismatches == 0)
}
