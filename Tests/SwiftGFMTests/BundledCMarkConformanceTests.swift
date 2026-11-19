// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftGFM
import Testing

// Unmodified upstream sources and reproduction details are in Fixtures/cmark-gfm.
private enum UpstreamSuite: String, CaseIterable, Sendable {
    case spec, extensions
    case fullInfo = "extensions-full-info-string"
    case tableStyle = "extensions-table-prefer-style-attributes"
}

private struct UpstreamExample: Sendable, CustomTestStringConvertible {
    let suite: UpstreamSuite
    let number: Int
    let section: String
    let startLine: Int
    let flags: [String]
    let markdown: String
    let expected: String

    var testDescription: String { "\(suite.rawValue)#\(number) (line \(startLine)): \(section)" }
    var isDisabled: Bool { flags.contains("disabled") }
    var ignoresExpectedOutput: Bool { expected.trimmingCharacters(in: .whitespacesAndNewlines) == "<IGNORE>" }
}

private enum FixtureError: Error {
    case missing(String)
    case malformed(String)
    case unsupportedFlag(String)
}

private enum UpstreamFixtures {
    static let all: [UpstreamExample] = {
        // An unreadable or malformed bundled corpus is a test infrastructure
        // failure, not an empty list of passing examples.
        do { return try UpstreamSuite.allCases.flatMap(load) } catch {
            fatalError("Could not load cmark-gfm fixtures: \(error)")
        }
    }()

    static let compared = all.filter { !$0.isDisabled && !$0.ignoresExpectedOutput }
    static let roundTrips = compared.filter { [.spec, .extensions, .fullInfo, .tableStyle].contains($0.suite) }

    private static func load(_ suite: UpstreamSuite) throws -> [UpstreamExample] {
        guard
            let url = Bundle.module.url(
                forResource: suite.rawValue, withExtension: "txt", subdirectory: "Fixtures/cmark-gfm")
        else {
            throw FixtureError.missing(suite.rawValue)
        }
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else { throw FixtureError.malformed(suite.rawValue) }
        // Splitting UTF-8 on LF avoids Swift Character's CRLF grapheme behavior:
        // regression example 1 deliberately contains CR + CR + LF.
        let bytes = Array(text.utf8)
        let lines = bytes.split(separator: 10, omittingEmptySubsequences: false)
        let fence = String(repeating: "`", count: 32)
        var state = 0
        var section = ""
        var start = 0
        var flags: [String] = []
        var input = ""
        var expected = ""
        var examples: [UpstreamExample] = []
        for (offset, bytes) in lines.enumerated() {
            let line = String(decoding: bytes, as: UTF8.self)
            let content = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let terminated = offset < lines.count - 1
            if state == 0 && content.hasPrefix(fence + " example") {
                state = 1
                start = offset + 1
                flags = content.dropFirst((fence + " example").count).split(whereSeparator: \.isWhitespace).map(
                    String.init)
                input = ""
                expected = ""
            } else if state != 0 && content == fence {
                guard state == 2 else { throw FixtureError.malformed("\(suite.rawValue):\(start)") }
                examples.append(
                    UpstreamExample(
                        suite: suite, number: examples.count + 1, section: section,
                        startLine: start, flags: flags, markdown: input.replacingOccurrences(of: "→", with: "\t"),
                        expected: expected.replacingOccurrences(of: "→", with: "\t")))
                state = 0
            } else if state == 1 && content == "." {
                state = 2
            } else if state == 1 {
                input += line + (terminated ? "\n" : "")
            } else if state == 2 {
                expected += line + (terminated ? "\n" : "")
            } else if line.hasPrefix("#") {
                let heading = line.drop(while: { $0 == "#" })
                if heading.first == " " { section = heading.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
        }
        guard state == 0 else { throw FixtureError.malformed("\(suite.rawValue): unterminated example") }
        return examples
    }
}

@Test func mathProfileMatchesBackendOnInputsWithoutDollars() throws {
    let examples = UpstreamFixtures.all.filter {
        !$0.isDisabled && !$0.markdown.contains("$") && !$0.markdown.utf8.contains(0)
    }
    #expect(!examples.isEmpty)
    let engine = MarkdownEngine()
    for example in examples {
        let parts = try engine.renderRecognizingMath(example.markdown).parts
        let html = parts.compactMap { part -> String? in
            if case .html(let value) = part { return value }
            return nil
        }.joined()
        #expect(
            parts.allSatisfy {
                if case .html = $0 { return true }
                return false
            }, "\(example.testDescription)")
        #expect(html == (try engine.render(example.markdown)), "\(example.testDescription)")
    }
}

private func configuration(for example: UpstreamExample) throws -> MarkdownConfiguration {
    var extensions: MarkdownExtensions = (example.suite == .extensions || example.suite == .tableStyle) ? .gfm : []
    var options: MarkdownOptions = [.allowUnsafeHTML]
    if example.suite == .extensions || example.suite == .tableStyle { options.insert(.footnotes) }
    if example.suite == .fullInfo { options.insert(.fullInfoString) }
    if example.suite == .tableStyle { options.insert(.tableStyleAttributes) }
    for flag in example.flags {
        switch flag {
        case "table": extensions.insert(.table)
        case "strikethrough": extensions.insert(.strikethrough)
        case "autolink": extensions.insert(.autolink)
        case "tagfilter": extensions.insert(.tagFilter)
        case "tasklist": extensions.insert(.taskList)
        case "footnotes": options.insert(.footnotes)
        default: throw FixtureError.unsupportedFlag(flag)
        }
    }
    return MarkdownConfiguration(extensions: extensions, options: options)
}

@Test("Bundled cmark-gfm examples: exact HTML bytes", arguments: UpstreamFixtures.compared)
private func bundledCMarkExample(_ example: UpstreamExample) throws {
    let actual = try MarkdownEngine(configuration: configuration(for: example)).render(example.markdown)
    #expect(
        Array(actual.utf8) == Array(example.expected.utf8),
        "\(example.testDescription)\nInput: \(String(reflecting: example.markdown))\nExpected: \(String(reflecting: example.expected))\nActual: \(String(reflecting: actual))"
    )
}

// Exact outputs independently obtained from the pinned upstream executable.
// The upstream round-trip runner normalizes HTML, masking these byte differences;
// examples 108 and 344 also change the number of spaces inside inline code.
private let knownRoundTripDifferences: [Int: String] = [
    51: "<h1>Foo <em>bar baz</em></h1>\n",
    52: "<h1>Foo <em>bar baz</em></h1>\n",
    65: "<h2>Foo Bar</h2>\n",
    108: "<p><code>   </code>\naaa</p>\n",
    344: "<p><code>\u{00a0}</code>\n<code>    </code></p>\n",
]

@Test("Bundled cmark-gfm examples: CommonMark round trip", arguments: UpstreamFixtures.roundTrips)
private func bundledRoundTrip(_ example: UpstreamExample) throws {
    let engine = MarkdownEngine(configuration: try configuration(for: example))
    let markdown = try engine.render(example.markdown, as: .commonMark)
    let html = try engine.render(markdown).replacingOccurrences(of: "<!-- end list -->\n", with: "")
    let reference = example.suite == .spec ? knownRoundTripDifferences[example.number] : nil
    let expected = reference ?? example.expected
    #expect(
        Array(html.utf8) == Array(expected.utf8),
        "\(example.testDescription)\nExpected: \(String(reflecting: expected))\nActual: \(String(reflecting: html))")
    if reference != nil {
        #expect(
            Array(html.utf8) != Array(example.expected.utf8),
            "A documented pinned-backend round-trip difference unexpectedly disappeared")
    }
}

@Test("Bundled cmark-gfm fixture inventory")
private func bundledCMarkInventory() {
    let bySuite = Dictionary(grouping: UpstreamFixtures.all, by: \.suite)
    #expect(bySuite[.spec]?.count == 672)
    #expect(bySuite[.extensions]?.count == 30)
    #expect(bySuite[.fullInfo]?.count == 4)
    #expect(bySuite[.tableStyle]?.count == 1)
    #expect(UpstreamFixtures.compared.count == 704)
    #expect(UpstreamFixtures.roundTrips.count == 704)
    #expect(
        UpstreamFixtures.roundTrips.filter { $0.suite == .spec && knownRoundTripDifferences[$0.number] != nil }.count
            == 5)
    #expect(UpstreamFixtures.all.filter(\.isDisabled).map(\.number) == [279, 280])
    #expect(
        UpstreamFixtures.all.filter(\.ignoresExpectedOutput).map { "\($0.suite.rawValue)#\($0.number)" } == [
            "extensions#20"
        ])
}

@Test("cmark-gfm spec example 279", .disabled("Marked disabled in the pinned upstream fixture"))
private func upstreamDisabled279() {}
@Test("cmark-gfm spec example 280", .disabled("Marked disabled in the pinned upstream fixture"))
private func upstreamDisabled280() {}
@Test(
    "cmark-gfm extensions example 20",
    .disabled("Upstream expected output is <IGNORE>, so there is no expected HTML to compare"))
private func upstreamIgnoredExtension20() {}
