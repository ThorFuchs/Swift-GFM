// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftGFM
import Testing

private struct EntityExample: Decodable, Sendable, CustomTestStringConvertible {
    let name: String
    let html: String
    var testDescription: String { "&\(name);" }
}

private struct EntityFixture: Decodable, Sendable {
    let revision: String
    let examples: [EntityExample]
}

private let entities: EntityFixture = {
    do {
        guard
            let url = Bundle.module.url(
                forResource: "entities-reference", withExtension: "json", subdirectory: "Fixtures/cmark-gfm")
        else {
            fatalError("Missing cmark-gfm entity reference fixture")
        }
        return try JSONDecoder().decode(EntityFixture.self, from: Data(contentsOf: url))
    } catch {
        fatalError("Invalid cmark-gfm entity reference fixture: \(error)")
    }
}()

@Test("Named entities match the pinned cmark-gfm executable", arguments: entities.examples)
private func entityMatchesReference(_ example: EntityExample) throws {
    let engine = MarkdownEngine(configuration: .init(extensions: [], options: [.allowUnsafeHTML]))
    let actual = try engine.render("&\(example.name);")
    #expect(
        Array(actual.utf8) == Array(example.html.utf8),
        "Entity &\(example.name); expected \(String(reflecting: example.html)); got \(String(reflecting: actual))")
}

@Test func entityFixtureInventory() {
    #expect(entities.revision == MarkdownEngine.backendRevision)
    #expect(entities.examples.count == 2_125)
    #expect(Set(entities.examples.map(\.name)).count == entities.examples.count)
}
