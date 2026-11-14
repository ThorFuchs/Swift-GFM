// SPDX-License-Identifier: Apache-2.0

/// A location exactly as reported by the pinned cmark backend. Columns follow
/// cmark's source-position rules and are not Swift `String.Index` values.
public struct MarkdownSourcePosition: Sendable, Equatable {
    /// Backend-reported line number.
    public let line: Int
    /// Backend-reported column number, not a Swift string index.
    public let column: Int
}

/// Raw source coordinates reported by cmark, whose end position is inclusive.
/// Some nodes have no range, including when `.sourcePositions` is disabled.
public struct MarkdownSourceRange: Sendable, Equatable {
    /// The first source coordinate reported by cmark.
    public let start: MarkdownSourcePosition
    /// The inclusive final coordinate reported by cmark.
    public let end: MarkdownSourcePosition
}

/// The marker style and, for ordered lists, its start and delimiter.
public enum MarkdownListStyle: Sendable, Equatable {
    /// A bulleted list.
    case bullet
    /// A numbered list.
    case ordered(start: Int, delimiter: MarkdownListDelimiter)
}

/// The punctuation following a numbered list marker.
public enum MarkdownListDelimiter: Sendable, Equatable {
    /// A period, as in `1.`.
    case period
    /// A closing parenthesis, as in `1)`.
    case parenthesis
}

/// Alignment of a GFM table column.
public enum MarkdownTableAlignment: Sendable, Equatable {
    /// No explicit alignment.
    case none
    /// Left alignment.
    case left
    /// Center alignment.
    case center
    /// Right alignment.
    case right
}

/// Fence details reported by cmark for a fenced code block.
public struct MarkdownCodeFence: Sendable, Equatable {
    /// The fence character, normally a backtick or tilde.
    public let character: Character
    /// The number of fence characters.
    public let length: Int
    /// The backend-reported indentation offset.
    public let offset: Int
}

/// The node kinds and properties exposed by this version of the cmark adapter.
/// Strings are the backend's parsed values, not necessarily original spelling.
public enum MarkdownNodeKind: Sendable, Equatable {
    /// The root document node.
    case document
    /// A block quotation.
    case blockQuote
    /// A list and its backend-reported tightness.
    case list(style: MarkdownListStyle, tight: Bool)
    /// A list item with its backend-reported index.
    case listItem(index: Int)
    /// A task-list item and its checked state.
    case taskListItem(index: Int, checked: Bool)
    /// A code block, its info string, and any fence metadata.
    case codeBlock(literal: String, info: String, fence: MarkdownCodeFence?)
    /// A raw HTML block.
    case htmlBlock(String)
    /// A backend custom block with enter and exit text.
    case customBlock(onEnter: String, onExit: String)
    /// A paragraph.
    case paragraph
    /// A heading with its level.
    case heading(level: Int)
    /// A thematic break.
    case thematicBreak
    /// Parsed text content.
    case text(String)
    /// A soft line break.
    case softBreak
    /// A hard line break.
    case lineBreak
    /// Inline code content.
    case code(String)
    /// Raw inline HTML.
    case htmlInline(String)
    /// A backend custom inline node with enter and exit text.
    case customInline(onEnter: String, onExit: String)
    /// Emphasized inline content.
    case emphasis
    /// Strongly emphasized inline content.
    case strong
    /// A link and its destination and title.
    case link(destination: String, title: String)
    /// An image and its destination and title.
    case image(destination: String, title: String)
    /// GFM strikethrough content.
    case strikethrough
    /// A table and its column alignments.
    case table(alignments: [MarkdownTableAlignment])
    /// A table row, indicating whether it is the header.
    case tableRow(isHeader: Bool)
    /// A table cell.
    case tableCell
    /// cmark's footnote definition literal. Footnotes require the option.
    case footnoteDefinition(literal: String)
    /// cmark's resolved reference literal, which may differ from the source label.
    case footnoteReference(literal: String)
}

// Flat storage avoids recursive deallocation for deeply nested documents.
// Each node value shares the same immutable, copy-on-write Array storage.
struct MarkdownNodeRecord: Sendable {
    let kind: MarkdownNodeKind
    let range: MarkdownSourceRange?
    let children: [Int]
}

/// An immutable Swift value, with no pointer into the backend's C tree.
/// A node retains the storage for its entire parsed document.
public struct MarkdownNode: Sendable {
    private let records: [MarkdownNodeRecord]
    private let index: Int

    init(records: [MarkdownNodeRecord], index: Int) {
        self.records = records
        self.index = index
    }

    /// Typed node identity and properties.
    public var kind: MarkdownNodeKind { records[index].kind }
    /// The backend's source range, when requested and available.
    public var range: MarkdownSourceRange? { records[index].range }
    /// Child nodes in backend order. Access constructs an array of node values.
    public var children: [MarkdownNode] {
        records[index].children.map { MarkdownNode(records: records, index: $0) }
    }

    /// Walk this node and its descendants in depth-first preorder.
    public func walk<V: MarkdownVisitor>(_ visitor: inout V) {
        MarkdownWalker.walk(self, visitor: &visitor)
    }

    /// Walk this node and its descendants with a throwing closure.
    public func walk(_ visit: (MarkdownNode) throws -> MarkdownWalkControl) rethrows {
        try MarkdownWalker.walk(self, visit: visit)
    }
}

/// A snapshot of one cmark parse and the configuration that produced it.
public struct MarkdownDocument: Sendable {
    /// The original source string supplied to the parser.
    public let source: String
    /// The backend configuration used to parse the source.
    public let configuration: MarkdownConfiguration
    /// The root of the Swift-owned tree.
    public let root: MarkdownNode

    /// Walks in depth-first preorder. Children retain their backend order.
    public func walk<V: MarkdownVisitor>(_ visitor: inout V) {
        MarkdownWalker.walk(root, visitor: &visitor)
    }

    /// Closure-based traversal also permits a caller to throw an error.
    public func walk(_ visit: (MarkdownNode) throws -> MarkdownWalkControl) rethrows {
        try MarkdownWalker.walk(root, visit: visit)
    }
}

/// Iterative depth-first traversal of a document or any subtree.
public enum MarkdownWalker {
    /// Walk a subtree with a visitor in depth-first preorder.
    public static func walk<V: MarkdownVisitor>(_ root: MarkdownNode, visitor: inout V) {
        walk(root) { visitor.visit($0) }
    }

    /// Walk a subtree with a potentially throwing closure.
    public static func walk(_ root: MarkdownNode, visit: (MarkdownNode) throws -> MarkdownWalkControl) rethrows {
        var pending = [root]
        while let node = pending.popLast() {
            switch try visit(node) {
            case .visitChildren:
                pending.append(contentsOf: node.children.reversed())
            case .skipChildren:
                continue
            case .stop:
                return
            }
        }
    }
}

/// Controls traversal after the current node has been visited.
public enum MarkdownWalkControl: Sendable {
    /// Continue into the node's children.
    case visitChildren
    /// Skip this node's children and continue elsewhere.
    case skipChildren
    /// End the traversal immediately.
    case stop
}

/// Called once for each node visited. Switch on `node.kind` for typed details.
public protocol MarkdownVisitor {
    /// Visits a node and decides whether traversal should continue.
    mutating func visit(_ node: MarkdownNode) -> MarkdownWalkControl
}
