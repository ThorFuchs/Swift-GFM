// SPDX-License-Identifier: Apache-2.0

internal import GitHubCMark

// C pointers never leave this conversion, which runs under MarkdownEngine's lock.
private struct Frame {
    let kind: MarkdownNodeKind
    let range: MarkdownSourceRange?
    var nextChild: OpaquePointer?
    var children: [Int] = []
}

func copyMarkdownTree(_ root: OpaquePointer, includeSourcePositions: Bool, limits: MarkdownResourceLimits) throws
    -> MarkdownNode
{
    var nodeCount = 0
    func frame(_ node: OpaquePointer, depth: Int) throws -> Frame {
        if let limit = limits.maximumASTDepth, depth > limit {
            throw MarkdownEngineError.resourceLimitExceeded(.astDepth, limit: limit, actual: depth)
        }
        nodeCount += 1
        if let limit = limits.maximumASTNodes, nodeCount > limit {
            throw MarkdownEngineError.resourceLimitExceeded(.astNodes, limit: limit, actual: nodeCount)
        }
        return Frame(
            kind: try nodeKind(node), range: includeSourcePositions ? sourceRange(node) : nil,
            nextChild: swiftgfm_cmark_node_first_child(node))
    }
    var stack = [try frame(root, depth: 1)]
    var records: [MarkdownNodeRecord] = []
    while !stack.isEmpty {
        let index = stack.count - 1
        if let child = stack[index].nextChild {
            stack[index].nextChild = swiftgfm_cmark_node_next(child)
            stack.append(try frame(child, depth: stack.count + 1))
        } else {
            let completed = stack.removeLast()
            let nodeIndex = records.count
            records.append(
                MarkdownNodeRecord(kind: completed.kind, range: completed.range, children: completed.children))
            if stack.isEmpty { return MarkdownNode(records: records, index: nodeIndex) }
            stack[stack.count - 1].children.append(nodeIndex)
        }
    }
    throw MarkdownEngineError.invalidASTNode("missing root")
}

private func sourceRange(_ node: OpaquePointer) -> MarkdownSourceRange? {
    let startLine = swiftgfm_cmark_node_get_start_line(node)
    guard startLine > 0 else { return nil }
    return MarkdownSourceRange(
        start: MarkdownSourcePosition(line: Int(startLine), column: Int(swiftgfm_cmark_node_get_start_column(node))),
        end: MarkdownSourcePosition(
            line: Int(swiftgfm_cmark_node_get_end_line(node)), column: Int(swiftgfm_cmark_node_get_end_column(node))))
}

private func string(_ pointer: UnsafePointer<CChar>?, _ context: String) throws -> String {
    guard let pointer else { throw MarkdownEngineError.invalidASTNode(context) }
    guard let result = String(validatingCString: pointer) else { throw MarkdownEngineError.invalidUTF8ASTNode(context) }
    return result
}

private func nodeKind(_ node: OpaquePointer) throws -> MarkdownNodeKind {
    let type = swiftgfm_bridge_node_get_type(node)
    // This cmark revision's type-string accessor returns "<unknown>" for its
    // built-in footnote types, so identify these two by their public enum values.
    if type == 0x800b {
        return .footnoteDefinition(literal: try string(swiftgfm_cmark_node_get_literal(node), "footnote definition"))
    }
    if type == 0xc00b {
        return .footnoteReference(literal: try string(swiftgfm_cmark_node_get_literal(node), "footnote reference"))
    }
    let name = try string(swiftgfm_cmark_node_get_type_string(node), "node type")
    func literal() throws -> String { try string(swiftgfm_cmark_node_get_literal(node), name) }
    switch name {
    case "document": return .document
    case "block_quote": return .blockQuote
    case "list":
        let style: MarkdownListStyle
        switch swiftgfm_bridge_node_get_list_type(node) {
        case 1: style = .bullet
        case 2:
            let delimiter: MarkdownListDelimiter
            switch swiftgfm_bridge_node_get_list_delim(node) {
            case 1: delimiter = .period
            case 2: delimiter = .parenthesis
            default: throw MarkdownEngineError.invalidASTNode("ordered list delimiter")
            }
            style = .ordered(start: Int(swiftgfm_cmark_node_get_list_start(node)), delimiter: delimiter)
        default: throw MarkdownEngineError.invalidASTNode("list style")
        }
        return .list(style: style, tight: swiftgfm_cmark_node_get_list_tight(node) != 0)
    case "item": return .listItem(index: Int(swiftgfm_cmark_node_get_item_index(node)))
    case "tasklist":
        return .taskListItem(
            index: Int(swiftgfm_cmark_node_get_item_index(node)),
            checked: swiftgfm_cmark_gfm_extensions_get_tasklist_item_checked(node))
    case "code_block":
        var length: Int32 = 0
        var offset: Int32 = 0
        var character: CChar = 0
        let fenced = swiftgfm_cmark_node_get_fenced(node, &length, &offset, &character) != 0
        let fence =
            fenced
            ? MarkdownCodeFence(
                character: Character(UnicodeScalar(UInt8(bitPattern: character))), length: Int(length),
                offset: Int(offset)) : nil
        return .codeBlock(
            literal: try literal(), info: try string(swiftgfm_cmark_node_get_fence_info(node), name), fence: fence)
    case "html_block": return .htmlBlock(try literal())
    case "custom_block":
        return .customBlock(
            onEnter: try string(swiftgfm_cmark_node_get_on_enter(node), name),
            onExit: try string(swiftgfm_cmark_node_get_on_exit(node), name))
    case "paragraph": return .paragraph
    case "heading": return .heading(level: Int(swiftgfm_cmark_node_get_heading_level(node)))
    case "thematic_break": return .thematicBreak
    case "text": return .text(try literal())
    case "softbreak": return .softBreak
    case "linebreak": return .lineBreak
    case "code": return .code(try literal())
    case "html_inline": return .htmlInline(try literal())
    case "custom_inline":
        return .customInline(
            onEnter: try string(swiftgfm_cmark_node_get_on_enter(node), name),
            onExit: try string(swiftgfm_cmark_node_get_on_exit(node), name))
    case "emph": return .emphasis
    case "strong": return .strong
    case "link":
        return .link(
            destination: try string(swiftgfm_cmark_node_get_url(node), name),
            title: try string(swiftgfm_cmark_node_get_title(node), name))
    case "image":
        return .image(
            destination: try string(swiftgfm_cmark_node_get_url(node), name),
            title: try string(swiftgfm_cmark_node_get_title(node), name))
    case "strikethrough": return .strikethrough
    case "table":
        let count = Int(swiftgfm_cmark_gfm_extensions_get_table_columns(node))
        let ptr = swiftgfm_cmark_gfm_extensions_get_table_alignments(node)
        guard count == 0 || ptr != nil else { throw MarkdownEngineError.invalidASTNode("table alignments") }
        let alignments: [MarkdownTableAlignment] = try (0..<count).map { index in
            switch ptr![index] {
            case 0: return .none
            case 108: return .left
            case 99: return .center
            case 114: return .right
            default: throw MarkdownEngineError.invalidASTNode("table alignment")
            }
        }
        return .table(alignments: alignments)
    case "table_header": return .tableRow(isHeader: true)
    case "table_row": return .tableRow(isHeader: false)
    case "table_cell": return .tableCell
    default: throw MarkdownEngineError.unsupportedASTNode(name: name, type: Int(type))
    }
}
