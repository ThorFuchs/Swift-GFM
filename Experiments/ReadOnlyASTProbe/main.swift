// An exploratory XML projection, not part of SwiftGFM's public API.
import Foundation
import FoundationXML
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

struct Node: Sendable {
    let kind: String
    let attributes: [String: String]
    let text: String?
    let children: [Node]
}

protocol Visitor {
    mutating func visit(_ node: Node)
}

func walk<V: Visitor>(_ node: Node, with visitor: inout V) {
    // Iterative traversal avoids depending on the Swift call stack for depth.
    var pending = [node]
    while let current = pending.popLast() {
        visitor.visit(current)
        pending.append(contentsOf: current.children.reversed())
    }
}

final class Frame {
    let kind: String
    let attributes: [String: String]
    var text = ""
    var children: [Node] = []

    init(_ kind: String, _ attributes: [String: String]) {
        self.kind = kind
        self.attributes = attributes
    }
}

final class Projection: NSObject, XMLParserDelegate {
    private var stack: [Frame] = []
    private(set) var root: Node?
    private(set) var unsupportedText = false
    private let literalKinds: Set<String> = ["text", "code", "code_block", "html_block", "html_inline"]

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        stack.append(Frame(name, attributes))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.text += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        let frame = stack.removeLast()
        let isLiteral = literalKinds.contains(frame.kind)
        if !isLiteral && !frame.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            unsupportedText = true
        }
        let node = Node(kind: frame.kind, attributes: frame.attributes,
                        text: isLiteral ? frame.text : nil, children: frame.children)
        if let parent = stack.last { parent.children.append(node) } else { root = node }
    }
}

enum ProjectionError: Error {
    case attributeWhitespaceWouldBeNormalized
    case invalidXML
    case unexpectedText
}

func project(_ xml: String) throws -> Node {
    // XML 1.0 parsers normalize raw attribute whitespace. Refuse it instead of
    // returning a silently changed tree; this prototype does not repair XML.
    var inTag = false
    var quote: Character?
    for char in xml {
        if let active = quote {
            if char == active { quote = nil }
            else if char == "\n" || char == "\r" || char == "\t" {
                throw ProjectionError.attributeWhitespaceWouldBeNormalized
            }
        } else if inTag && (char == "\"" || char == "'") {
            quote = char
        } else if char == "<" { inTag = true }
        else if char == ">" { inTag = false }
    }
    let delegate = Projection()
    let parser = XMLParser(data: Data(xml.utf8))
    parser.shouldResolveExternalEntities = false
    parser.delegate = delegate
    guard parser.parse(), let root = delegate.root else { throw ProjectionError.invalidXML }
    guard !delegate.unsupportedText else { throw ProjectionError.unexpectedText }
    return root
}

struct Collector: Visitor {
    var kinds: [String] = []
    var literals: [String] = []
    mutating func visit(_ node: Node) {
        kinds.append(node.kind)
        if let text = node.text { literals.append(text) }
    }
}

@main struct Main {
    static func main() async {
        do {
            let xml = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
            let root = try project(xml)
            let result = await Task.detached {
                var collector = Collector()
                walk(root, with: &collector)
                return collector
            }.value
            print("kinds: \(result.kinds.joined(separator: ", "))")
            print("literals: \(result.literals)")
        } catch {
            FileHandle.standardError.write(Data("Projection rejected: \(error)\n".utf8))
            exit(1)
        }
    }
}
