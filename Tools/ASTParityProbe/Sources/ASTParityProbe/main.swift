// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftGFM

struct Input: Decodable {
    let markdown: String
    let extensions: [String]
}
struct Tree: Encodable {
    let kind: String
    let attributes: [String: String]
    let literal: String?
    let children: [Tree]
}
struct Output: Encodable {
    let tree: Tree?
    let error: String?
}

func project(_ node: MarkdownNode, alignments: [MarkdownTableAlignment] = [], header: Bool = false, cellIndex: Int = 0)
    -> Tree
{
    var attrs: [String: String] = [:]
    var literal: String?
    var tableAlignments = alignments
    var isHeader = header
    if let range = node.range {
        attrs["sourcepos"] = "\(range.start.line):\(range.start.column)-\(range.end.line):\(range.end.column)"
    }
    let kind: String
    switch node.kind {
    case .document: kind = "document"
    case .blockQuote: kind = "block_quote"
    case .list(let style, let tight):
        kind = "list"
        attrs["tight"] = tight ? "true" : "false"
        switch style {
        case .bullet: attrs["type"] = "bullet"
        case .ordered(let start, let delimiter):
            attrs["type"] = "ordered"
            attrs["start"] = String(start)
            attrs["delim"] = delimiter == .period ? "period" : "paren"
        }
    case .listItem: kind = "item"
    case .taskListItem(_, let checked):
        kind = "tasklist"
        attrs["completed"] = checked ? "true" : "false"
    case .codeBlock(let text, let info, _):
        kind = "code_block"
        literal = text
        if !info.isEmpty { attrs["info"] = info }
    case .htmlBlock(let text):
        kind = "html_block"
        literal = text
    case .customBlock(let enter, let exit):
        kind = "custom_block"
        attrs["on_enter"] = enter
        attrs["on_exit"] = exit
    case .paragraph: kind = "paragraph"
    case .heading(let level):
        kind = "heading"
        attrs["level"] = String(level)
    case .thematicBreak: kind = "thematic_break"
    case .text(let text):
        kind = "text"
        literal = text
    case .softBreak: kind = "softbreak"
    case .lineBreak: kind = "linebreak"
    case .code(let text):
        kind = "code"
        literal = text
    case .htmlInline(let text):
        kind = "html_inline"
        literal = text
    case .customInline(let enter, let exit):
        kind = "custom_inline"
        attrs["on_enter"] = enter
        attrs["on_exit"] = exit
    case .emphasis: kind = "emph"
    case .strong: kind = "strong"
    case .link(let destination, let title):
        kind = "link"
        attrs["destination"] = destination
        attrs["title"] = title
    case .image(let destination, let title):
        kind = "image"
        attrs["destination"] = destination
        attrs["title"] = title
    case .strikethrough: kind = "strikethrough"
    case .table(let values):
        kind = "table"
        tableAlignments = values
    case .tableRow(let value):
        kind = value ? "table_header" : "table_row"
        isHeader = value
    case .tableCell:
        kind = "table_cell"
        if isHeader && cellIndex < tableAlignments.count {
            switch tableAlignments[cellIndex] {
            case .none: break
            case .left: attrs["align"] = "left"
            case .center: attrs["align"] = "center"
            case .right: attrs["align"] = "right"
            }
        }
    case .footnoteDefinition, .footnoteReference:
        kind = "footnote-not-representable-in-cmark-xml"
    }
    return Tree(
        kind: kind, attributes: attrs, literal: literal,
        children: node.children.enumerated().map {
            project($0.element, alignments: tableAlignments, header: isHeader, cellIndex: $0.offset)
        })
}

while let line = readLine() {
    do {
        let input = try JSONDecoder().decode(Input.self, from: Data(line.utf8))
        var extensions: MarkdownExtensions = []
        for name in input.extensions {
            switch name {
            case "table": extensions.insert(.table)
            case "strikethrough": extensions.insert(.strikethrough)
            case "autolink": extensions.insert(.autolink)
            case "tagfilter": extensions.insert(.tagFilter)
            case "tasklist": extensions.insert(.taskList)
            default: throw MarkdownEngineError.extensionUnavailable(name)
            }
        }
        let document = try MarkdownEngine(configuration: .init(extensions: extensions, options: [.sourcePositions]))
            .parse(input.markdown)
        let data = try JSONEncoder().encode(Output(tree: project(document.root), error: nil))
        print(String(decoding: data, as: UTF8.self))
    } catch {
        let data = try JSONEncoder().encode(Output(tree: nil, error: String(describing: error)))
        print(String(decoding: data, as: UTF8.self))
    }
}
