import Foundation
import Markdown
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif
let args = CommandLine.arguments.dropFirst()
guard let mode = args.first, ["html", "tree", "details", "ast-json"].contains(mode), args.count == 1 else {
    FileHandle.standardError.write(Data("usage: markdown-probe html|tree|details|ast-json\n".utf8)); exit(2)
}
let input = FileHandle.standardInput.readDataToEndOfFile()
guard let source = String(data: input, encoding: .utf8) else {
    FileHandle.standardError.write(Data("input is not UTF-8\n".utf8)); exit(2)
}
let document = Document(parsing: source, options: .disableSmartOpts)
func summarize(_ node: any Markup) -> String {
    var text = ""
    if let link = node as? Link { text += "link destination=\(String(reflecting: link.destination)) title=\(String(reflecting: link.title))\n" }
    if let image = node as? Image { text += "image source=\(String(reflecting: image.source)) title=\(String(reflecting: image.title))\n" }
    if let textNode = node as? Text { text += "text=\(String(reflecting: textNode.string))\n" }
    for child in node.children { text += summarize(child) }
    return text
}
struct ProjectedNode: Encodable {
    var kind: String
    var attributes: [String: String] = [:]
    var children: [ProjectedNode]
}
func project(_ node: any Markup) -> ProjectedNode {
    var kind = String(reflecting: type(of: node))
    var attributes: [String: String] = [:]
    switch node {
    case is Document: kind = "document"
    case is Paragraph: kind = "paragraph"
    case is BlockQuote: kind = "block_quote"
    case let value as OrderedList: kind = "list"; attributes["type"] = "ordered"; attributes["start"] = String(value.startIndex)
    case is UnorderedList: kind = "list"; attributes["type"] = "bullet"
    case let value as ListItem:
        kind = "item"
        if let checkbox = value.checkbox { attributes["checkbox"] = checkbox == .checked ? "checked" : "unchecked" }
    case let value as Heading: kind = "heading"; attributes["level"] = String(value.level)
    case is ThematicBreak: kind = "thematic_break"
    case let value as CodeBlock: kind = "code_block"; attributes["literal"] = value.code; if let info = value.language { attributes["info"] = info }
    case let value as HTMLBlock: kind = "html_block"; attributes["literal"] = value.rawHTML
    case let value as Link: kind = "link"; if let destination = value.destination { attributes["destination"] = destination }; if let title = value.title { attributes["title"] = title }
    case let value as Image: kind = "image"; if let source = value.source { attributes["destination"] = source }; if let title = value.title { attributes["title"] = title }
    case let value as Text: kind = "text"; attributes["literal"] = value.string
    case let value as InlineCode: kind = "code"; attributes["literal"] = value.code
    case let value as InlineHTML: kind = "html_inline"; attributes["literal"] = value.rawHTML
    case is SoftBreak: kind = "softbreak"
    case is LineBreak: kind = "linebreak"
    case is Emphasis: kind = "emph"
    case is Strong: kind = "strong"
    case is Strikethrough: kind = "strikethrough"
    case is Table: kind = "table"
    case is Table.Head: kind = "table_header"
    case is Table.Body: kind = "table_body"
    case is Table.Row: kind = "table_row"
    case is Table.Cell: kind = "table_cell"
    default: break
    }
    return ProjectedNode(kind: kind, attributes: attributes, children: node.children.map { project($0) })
}
if mode == "ast-json" {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    do { FileHandle.standardOutput.write(try encoder.encode(project(document))) }
    catch { FileHandle.standardError.write(Data("JSON encoding failed: \(error)\n".utf8)); exit(2) }
} else {
    let result = mode == "html" ? HTMLFormatter.format(document) : mode == "details" ? summarize(document) : document.debugDescription() + "\n"
    FileHandle.standardOutput.write(Data(result.utf8))
}
